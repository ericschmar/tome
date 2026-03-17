import Foundation
import OSLog
import SwiftData
import Combine
internal import CoreData
internal import CloudKit

private let logger = Logger(subsystem: "com.ericschmar.tome", category: "cloudkit-sync")

/// Monitors iCloud sync progress for SwiftData
@MainActor
@Observable
class CloudSyncMonitor {
    static let shared = CloudSyncMonitor()

    /// Whether sync is currently active
    var isSyncing = false

    /// Sync progress (0.0 to 1.0)
    var syncProgress: Double = 0.0

    /// Last sync error, if any
    var lastError: Error?

    /// Last successful sync timestamp
    var lastSyncDate: Date?

    struct SyncEvent: Identifiable {
        let id = UUID()
        let date: Date
        let type: String
        let succeeded: Bool
        let errorDescription: String?
    }

    /// Rolling log of the last 30 sync events
    var eventLog: [SyncEvent] = []

    private var isSetUp = false
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNotificationObservers()
    }

    deinit {
        cancellables.removeAll()
    }

    private func setupNotificationObservers() {
        guard !isSetUp else { return }
        isSetUp = true

        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isSyncing = true
                self?.lastSyncDate = Date()
                Task { await self?.animateProgress() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleCloudKitEvent(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isSyncing = false
                self?.syncProgress = 0.0
            }
            .store(in: &cancellables)
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else { return }

        if event.endDate == nil {
            isSyncing = true
        } else {
            if let error = event.error { lastError = error }
            if event.succeeded && event.type == .import { lastSyncDate = event.endDate }
            isSyncing = false
            syncProgress = 1.0

            let typeName: String
            switch event.type {
            case .setup: typeName = "Setup"
            case .import: typeName = "Import"
            case .export: typeName = "Export"
            @unknown default: typeName = "Unknown"
            }
            let errorSummary: String?
            if event.succeeded {
                logger.info("Sync \(typeName) succeeded")
                errorSummary = nil
            } else if let error = event.error as? CKError {
                logger.error("Sync \(typeName) failed: \(error.localizedDescription)")
                if error.code == .partialFailure,
                   let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
                    for (itemID, itemError) in partialErrors {
                        logger.error("  Record \(String(describing: itemID)): \(itemError.localizedDescription)")
                    }
                    let details = partialErrors.map { "\($0.key): \($0.value.localizedDescription)" }.joined(separator: "; ")
                    errorSummary = "Partial failure (\(partialErrors.count) records): \(details)"
                } else {
                    errorSummary = error.localizedDescription
                }
            } else if let error = event.error {
                logger.error("Sync \(typeName) failed: \(error.localizedDescription)")
                errorSummary = error.localizedDescription
            } else {
                errorSummary = nil
            }

            let entry = SyncEvent(
                date: event.endDate ?? Date(),
                type: typeName,
                succeeded: event.succeeded,
                errorDescription: errorSummary
            )
            eventLog.insert(entry, at: 0)
            if eventLog.count > 30 { eventLog.removeLast() }
        }
    }

    private func animateProgress() async {
        syncProgress = 0.0

        for i in 0...19 {
            guard isSyncing else { return }
            syncProgress = Double(i) / 20.0
            try? await Task.sleep(for: .milliseconds(100))
        }

        try? await Task.sleep(for: .milliseconds(300))
        syncProgress = 1.0
        try? await Task.sleep(for: .seconds(1))
        isSyncing = false
        syncProgress = 0.0
    }

    var statusMessage: String {
        if isSyncing { return "Syncing with iCloud..." }

        if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        }

        return "iCloud sync enabled"
    }

    var lastSyncFormatted: String {
        guard let lastSync = lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}
