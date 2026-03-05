import Foundation
import SwiftData
import Combine
import CoreData
internal import CloudKit

/// Monitors iCloud sync progress for SwiftData
@MainActor
@Observable
class CloudSyncMonitor {
    static let shared = CloudSyncMonitor()
    
    /// Whether sync is currently active
    var isSyncing = false
    
    /// Sync progress (0.0 to 1.0)
    var syncProgress: Double = 0.0
    
    /// Number of items being imported
    var importingCount: Int = 0
    
    /// Number of items being exported
    var exportingCount: Int = 0
    
    /// Last sync error, if any
    var lastError: Error?
    
    /// Last successful sync timestamp
    var lastSyncDate: Date?
    
    /// Whether sync has been set up
    private var isSetUp = false
    
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationObservers()
        
        // Debug: Check CloudKit status on init
        Task {
            await checkCloudKitStatus()
        }
    }
    
    /// Debug helper to check CloudKit configuration
    private func checkCloudKitStatus() async {
        print("🔍 Checking CloudKit status...")
        
        let container = CKContainer.default()
        print("   Container ID: \(container.containerIdentifier ?? "nil")")
        
        do {
            let status = try await container.accountStatus()
            print("   Account Status: \(status)")
            
            switch status {
            case .available:
                print("   ✅ CloudKit is ready to sync")
            case .noAccount:
                print("   ⚠️ User not signed into iCloud")
            case .restricted:
                print("   ⚠️ iCloud access is restricted")
            case .couldNotDetermine:
                print("   ❓ Could not determine iCloud status")
            case .temporarilyUnavailable:
                print("   ⏳ iCloud temporarily unavailable")
            @unknown default:
                print("   ❓ Unknown iCloud status")
            }
        } catch {
            print("   ❌ Error checking CloudKit status: \(error)")
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    /// Set up notification observers for CloudKit sync events
    private func setupNotificationObservers() {
        guard !isSetUp else { return }
        isSetUp = true
        
        // Observe remote change notifications
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                print("📥 NSPersistentStoreRemoteChange received")
                self?.handleRemoteChange(notification)
            }
            .store(in: &cancellables)
        
        // Also listen for CloudKit account changes
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                print("☁️ CloudKit account changed")
                self?.handleAccountChange(notification)
            }
            .store(in: &cancellables)
    }
    
    /// Handle remote change notification
    private func handleRemoteChange(_ notification: Notification) {
        print("📥 CloudKit remote change detected")
        
        // Extract information from the notification if available
        if let userInfo = notification.userInfo {
            print("   User info: \(userInfo)")
            
            // Mark as syncing
            isSyncing = true
            
            // Simulate progress (since SwiftData doesn't expose detailed progress)
            Task {
                await animateProgress()
            }
            
            lastSyncDate = Date()
        }
    }
    
    /// Handle CloudKit account change
    private func handleAccountChange(_ notification: Notification) {
        print("☁️ CloudKit account changed - user may have signed in/out of iCloud")
        // Reset sync state
        isSyncing = false
        syncProgress = 0.0
    }
    
    /// Animate sync progress indicator
    private func animateProgress() async {
        syncProgress = 0.0
        
        // Animate from 0 to 0.95 over 2 seconds
        for i in 0...19 {
            guard isSyncing else { return }
            syncProgress = Double(i) / 20.0
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        // Wait a moment at 95%
        try? await Task.sleep(for: .milliseconds(300))
        
        // Complete
        syncProgress = 1.0
        
        // Wait before hiding
        try? await Task.sleep(for: .seconds(1))
        
        isSyncing = false
        syncProgress = 0.0
    }
    
    /// Manually trigger a sync check
    func checkSyncStatus() {
        // In SwiftData with CloudKit, syncing happens automatically
        // We can't manually trigger it, but we can reset our state
        if !isSyncing {
            syncProgress = 0.0
            importingCount = 0
            exportingCount = 0
        }
    }
    
    /// Force the system to check for remote changes
    /// This sends a notification that might wake up CloudKit sync
    func forceSyncCheck() {
        print("🔄 Requesting sync check...")
        
        // Post a notification that the app is interested in remote changes
        // This might encourage the system to check for updates sooner
        NotificationCenter.default.post(
            name: Notification.Name("RequestCloudKitSync"),
            object: nil
        )
        
        // Also manually check account status
        Task {
            await checkCloudKitStatus()
        }
    }
    
    /// Get a user-friendly sync status message
    var statusMessage: String {
        if isSyncing {
            if importingCount > 0 && exportingCount > 0 {
                return "Syncing \(importingCount + exportingCount) items..."
            } else if importingCount > 0 {
                return "Importing \(importingCount) items..."
            } else if exportingCount > 0 {
                return "Exporting \(exportingCount) items..."
            } else {
                return "Syncing with iCloud..."
            }
        }
        
        if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        }
        
        return "iCloud sync enabled"
    }
    
    /// Formatted last sync time
    var lastSyncFormatted: String {
        guard let lastSync = lastSyncDate else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}
