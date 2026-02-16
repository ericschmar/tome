import Foundation

extension String {
    /// Normalizes a string for search by converting to lowercase, removing diacritics,
    /// and trimming whitespace for better fuzzy matching
    func normalizedForSearch() -> String {
        return self
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
