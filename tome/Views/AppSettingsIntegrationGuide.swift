import SwiftUI

/// Example showing how to integrate AppSettings into your main app
///
/// Usage in your App struct:
///
/// ```swift
/// @main
/// struct YourApp: App {
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .applyAppTheme() // Apply theme settings
///         }
///     }
/// }
/// ```
///
/// Accessing settings anywhere in your app:
///
/// ```swift
/// struct SomeView: View {
///     @State private var settings = AppSettings.shared
///     
///     var body: some View {
///         Text("Default language: \(settings.defaultBookLanguage.displayName)")
///     }
/// }
/// ```
///
/// The settings are automatically persisted using UserDefaults and will
/// survive app restarts.

// Example implementation guide (do not add to project, just for reference)
