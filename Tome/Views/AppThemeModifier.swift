import SwiftUI

/// View modifier to apply app theme settings
struct AppThemeModifier: ViewModifier {
    @State private var settings = AppSettings.shared
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(settings.theme.colorScheme)
    }
}

extension View {
    /// Apply the app's theme settings to this view
    func applyAppTheme() -> some View {
        modifier(AppThemeModifier())
    }
}
