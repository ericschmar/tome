import SwiftUI

/// App-wide settings manager using AppStorage for persistence
@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    // MARK: - Settings Properties
    
    /// App theme preference
    var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
        }
    }
    
    /// Default language for books
    var defaultBookLanguage: BookLanguage {
        didSet {
            UserDefaults.standard.set(defaultBookLanguage.rawValue, forKey: "defaultBookLanguage")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load theme
        if let themeRawValue = UserDefaults.standard.string(forKey: "appTheme"),
           let savedTheme = AppTheme(rawValue: themeRawValue) {
            self.theme = savedTheme
        } else {
            self.theme = .system
        }
        
        // Load default book language
        if let languageRawValue = UserDefaults.standard.string(forKey: "defaultBookLanguage"),
           let savedLanguage = BookLanguage(rawValue: languageRawValue) {
            self.defaultBookLanguage = savedLanguage
        } else {
            self.defaultBookLanguage = .english
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear the image cache
    func clearImageCache() {
        // TODO: Implement image cache clearing logic
        // This will depend on your caching implementation
        // For example, if using URLCache:
        URLCache.shared.removeAllCachedResponses()
        
        // If you have a custom image cache service, call it here
        // ImageCacheService.shared.clearCache()
    }
    
    /// Get the estimated cache size
    func getImageCacheSize() -> String {
        let cache = URLCache.shared
        let currentDiskUsage = cache.currentDiskUsage
        let currentMemoryUsage = cache.currentMemoryUsage
        
        let totalBytes = currentDiskUsage + currentMemoryUsage
        return ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
    
    // MARK: - Reset Settings
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        theme = .system
        defaultBookLanguage = .english
    }
}

// MARK: - AppTheme

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
}

// MARK: - BookLanguage

enum BookLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case russian = "ru"
    case arabic = "ar"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .spanish:
            return "Spanish"
        case .french:
            return "French"
        case .german:
            return "German"
        case .italian:
            return "Italian"
        case .portuguese:
            return "Portuguese"
        case .chinese:
            return "Chinese"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        case .russian:
            return "Russian"
        case .arabic:
            return "Arabic"
        }
    }
    
    var flag: String {
        switch self {
        case .english:
            return "🇺🇸"
        case .spanish:
            return "🇪🇸"
        case .french:
            return "🇫🇷"
        case .german:
            return "🇩🇪"
        case .italian:
            return "🇮🇹"
        case .portuguese:
            return "🇵🇹"
        case .chinese:
            return "🇨🇳"
        case .japanese:
            return "🇯🇵"
        case .korean:
            return "🇰🇷"
        case .russian:
            return "🇷🇺"
        case .arabic:
            return "🇸🇦"
        }
    }

    /// Convert 2-letter code to 3-letter ISO 639-2/B code
    var threeLetterCode: String {
        switch self {
        case .english: return "eng"
        case .spanish: return "spa"
        case .french: return "fre"
        case .german: return "ger"
        case .italian: return "ita"
        case .portuguese: return "por"
        case .chinese: return "chi"
        case .japanese: return "jpn"
        case .korean: return "kor"
        case .russian: return "rus"
        case .arabic: return "ara"
        }
    }
}
