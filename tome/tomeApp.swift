//
//  tomeApp.swift
//  tome
//
//  Created by Eric Schmar on 2/10/26.
//

import SwiftUI
import SwiftData

@main
struct tomeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            Tag.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema, 
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic  // Enable CloudKit integration
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Migration failed - delete the old store and create a fresh one
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            
            // Try creating the container again with fresh storage
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
    }
}
