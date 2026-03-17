//
//  tomeApp.swift
//  tome
//
//  Created by Eric Schmar on 2/10/26.
//

import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.ericschmar.tome", category: "startup")

#if os(iOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Must be called within 30s — signals to iOS that this app reliably handles CloudKit
        // silent pushes. Without this, iOS deprioritizes future push delivery.
        completionHandler(.newData)
    }
}
#endif

@main
struct tomeApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    /// Set to the backup URL if the store was nuked at startup, so the UI can warn the user.
    static var storeResetBackupURL: URL? = nil

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            Tag.self,
        ])

        let cloudKitContainerIdentifier = "iCloud.com.ericschmar.tome"

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Migration failed - back up the corrupt store, then delete it and start fresh.
            // ⚠️ WARNING: This path destroys local data and restarts from scratch.
            // If this fires, CloudKit sync will not have the lost records.
            logger.error("ModelContainer init failed, nuking local store: \(error)")

            let storeURL = modelConfiguration.url
            let fm = FileManager.default

            // Back up the SQLite triplet (.sqlite, .sqlite-wal, .sqlite-shm) before deleting.
            let backupDir = storeURL.deletingLastPathComponent()
                .appendingPathComponent("StoreBackup-\(Int(Date().timeIntervalSince1970))", isDirectory: true)
            if (try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)) != nil {
                for ext in ["", "-wal", "-shm"] {
                    let src = URL(fileURLWithPath: storeURL.path + ext)
                    let dst = backupDir.appendingPathComponent(src.lastPathComponent)
                    try? fm.copyItem(at: src, to: dst)
                }
                tomeApp.storeResetBackupURL = backupDir
                logger.info("Corrupt store backed up to: \(backupDir.path)")
            }

            try? fm.removeItem(at: storeURL)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    // Initialize eagerly so notification observers are registered before the first
    // NSPersistentCloudKitContainer sync events fire at startup.
    private let syncMonitor = CloudSyncMonitor.shared

    @State private var navigationState = NavigationState()
    @State private var showStoreResetAlert = false

    var body: some Scene {
        WindowGroup("Tome") {
            NavigationRootView()
                .environment(navigationState)
                .applyAppTheme()
                .task {
                    await migrateLibraryCoverData()
                }
                .onAppear {
                    showStoreResetAlert = tomeApp.storeResetBackupURL != nil
                }
                .alert("Library Reset", isPresented: $showStoreResetAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    if let backupURL = tomeApp.storeResetBackupURL {
                        Text("The local database could not be opened and was reset. A backup was saved to:\n\n\(backupURL.path)\n\nIf you have iCloud sync enabled, your books should restore automatically.")
                    } else {
                        Text("The local database could not be opened and was reset. If you have iCloud sync enabled, your books should restore automatically.")
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1440, height: 900)
    }

    /// One-time migration: nil out coverImageData for OpenLibrary books (those with a coverID).
    /// These books have a coverURL and the ImageCacheService will serve them from disk or re-fetch.
    /// User-uploaded images (no coverID) are left alone; @Attribute(.externalStorage) on
    /// coverImageData ensures they sync to CloudKit as a CKAsset.
    private func migrateLibraryCoverData() async {
        let key = "didMigrateCoverDataToExternalV1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.coverImageData != nil }
        )

        do {
            let books = try context.fetch(descriptor)
            let toMigrate = books.filter { $0.coverID != nil }
            logger.info("Cover migration: \(toMigrate.count) OpenLibrary books, \(books.count - toMigrate.count) user-uploaded books")
            for book in toMigrate {
                book.coverImageData = nil
            }
            try context.save()
            UserDefaults.standard.set(true, forKey: key)
            logger.info("Cover migration complete")
        } catch {
            logger.error("Cover migration failed: \(error)")
        }
    }
}
