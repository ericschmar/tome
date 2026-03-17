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
            // Migration failed - delete the old store and create a fresh one
            // ⚠️ WARNING: This path destroys local data and restarts from scratch.
            // If this fires, CloudKit sync will not have the lost records.
            logger.error("ModelContainer init failed, nuking local store: \(error)")
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)

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

    var body: some Scene {
        WindowGroup("Tome") {
            NavigationRootView()
                .environment(navigationState)
                .applyAppTheme()
                .task {
                    await migrateLibraryCoverData()
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
