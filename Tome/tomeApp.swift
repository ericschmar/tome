//
//  tomeApp.swift
//  tome
//
//  Created by Eric Schmar on 2/10/26.
//

import SwiftUI
import SwiftData

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
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    @State private var navigationState = NavigationState()

    var body: some Scene {
        WindowGroup("Tome") {
            NavigationRootView()
                .environment(navigationState)
                .applyAppTheme()
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1440, height: 900)
    }
}
