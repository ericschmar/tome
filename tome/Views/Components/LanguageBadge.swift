import SwiftUI

/// Language badge component with refined, semantic colors
struct LanguageBadge: View {
    let languageCode: String

    // Refined palette - inspired by macOS system colors
    private static let colorPalette: [(hex: String, name: String)] = [
        ("#007AFF", "blue"),      // System blue
        ("#5856D6", "purple"),    // System purple
        ("#AF52DE", "pink"),      // System pink
        ("#FF375F", "berry"),     // Berry
        ("#FF9F0A", "orange"),    // System orange
        ("#FFD60A", "yellow"),    // System yellow
        ("#30D158", "green"),     // System green
        ("#64D2FF", "teal"),      // Teal
        ("#5AC8FA", "cyan"),      // Cyan
        ("#BF5AF2", "violet"),    // Violet
        ("#8E8E93", "gray")       // System gray
    ]

    private static let languageNames: [String: String] = [
        "eng": "English",
        "fre": "French",
        "spa": "Spanish",
        "ger": "German",
        "ita": "Italian",
        "por": "Portuguese",
        "rus": "Russian",
        "jpn": "Japanese",
        "chi": "Chinese",
        "kor": "Korean",
        "ara": "Arabic",
        "hin": "Hindi",
        "dut": "Dutch",
        "pol": "Polish",
        "swe": "Swedish",
        "nor": "Norwegian",
        "dan": "Danish",
        "fin": "Finnish",
        "tur": "Turkish",
        "grc": "Greek",
        "heb": "Hebrew",
        "tha": "Thai",
        "vie": "Vietnamese",
        "ind": "Indonesian",
        "msa": "Malay"
    ]

    var body: some View {
        Text(displayName)
            .font(.system(size: 11, weight: .medium, design: .default))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var displayName: String {
        Self.languageNames[languageCode] ?? languageCode.uppercased()
    }

    private var color: Color {
        Color(hex: Self.color(for: languageCode)) ?? .blue
    }

    private static func color(for code: String) -> String {
        // Hash-based color selection
        let hash = code.hashValue
        let index = abs(hash) % colorPalette.count
        return colorPalette[index].hex
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Text("Language Badges")
            .font(.headline)

        HStack(spacing: 6) {
            LanguageBadge(languageCode: "eng")
            LanguageBadge(languageCode: "fre")
            LanguageBadge(languageCode: "spa")
            LanguageBadge(languageCode: "ger")
        }

        HStack(spacing: 6) {
            LanguageBadge(languageCode: "ita")
            LanguageBadge(languageCode: "jpn")
            LanguageBadge(languageCode: "chi")
            LanguageBadge(languageCode: "kor")
        }

        HStack(spacing: 6) {
            LanguageBadge(languageCode: "rus")
            LanguageBadge(languageCode: "por")
            LanguageBadge(languageCode: "unknown")
        }
    }
    .padding()
}
