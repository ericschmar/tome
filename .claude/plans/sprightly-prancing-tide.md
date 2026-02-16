# Plan: Convert Language Display from Tag Cloud to List Format

## Context

The languages section in the book detail view currently displays as a "tag cloud" using `FlowingLayout` with colored `LanguageBadge` components. This differs from the publishers section, which uses a smart list display with an overflow popover. This plan aligns the languages section with the publishers section for UI consistency and adds language preference awareness.

**Current behavior:**
- All languages are shown as colored badges in a flowing tag cloud layout
- No consideration for user's language preference

**Desired behavior:**
- Display languages in a list format like publishers (chips with overflow popover)
- Prioritize the user's default language setting
- Only show the default language if the book supports it; otherwise show all languages

## Implementation

### 1. Add Language Code Mapping Helper (BookLanguage extension)

**File:** `/Users/mmacbook/develop/Tome/Tome/Views/AppSettings.swift`

Add a helper to convert between 2-letter ISO 639-1 codes (used in `BookLanguage`) and 3-letter ISO 639-2/B codes (stored in book data):

```swift
// Add to BookLanguage enum (after line 189)
extension BookLanguage {
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
```

### 2. Add State Variable for Languages Popover

**File:** `/Users/mmacbook/develop/Tome/Tome/Views/BookContentView.swift`

Add after line 15 (after `showingAllPublishers`):

```swift
@State private var showingAllLanguages = false
```

### 3. Replace Languages Section Implementation

**File:** `/Users/mmacbook/develop/Tome/Tome/Views/BookContentView.swift`

Replace lines 192-207 (current tag cloud implementation) with:

```swift
// Languages
if !source.languages.isEmpty {
    GridRow(alignment: .firstTextBaseline) {
        Text("Language")
            .gridColumnAlignment(.leading)
            .frame(width: 90, alignment: .leading)
            .font(.system(size: 13, weight: .medium, design: .default))
            .foregroundStyle(.secondary)

        languagesChips
    }
}
```

### 4. Add languagesChips Computed Property

**File:** `/Users/mmacbook/develop/Tome/Tome/Views/BookContentView.swift`

Add after the `publishersChips` property (after line 327):

```swift
private var languagesChips: some View {
    // Get the default language code (3-letter format)
    let defaultLanguageCode = AppSettings.shared.defaultBookLanguage.threeLetterCode

    // Determine which languages to display
    let sortedLanguages = source.languages.sorted()

    // If book supports the default language, only show that language
    if sortedLanguages.contains(defaultLanguageCode) {
        LanguageBadge(languageCode: defaultLanguageCode)
            .textSelection(.enabled)
    } else {
        // Book doesn't support default language, show all with overflow pattern
        HStack(spacing: 6) {
            if sortedLanguages.count <= 2 {
                ForEach(sortedLanguages, id: \.self) { lang in
                    LanguageBadge(languageCode: lang)
                        .textSelection(.enabled)
                }
            } else {
                LanguageBadge(languageCode: sortedLanguages[0])
                    .textSelection(.enabled)

                if sortedLanguages.count > 1 {
                    Button {
                        showingAllLanguages = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .semibold))
                            Text("\(sortedLanguages.count - 1) more")
                                .font(.system(size: 12, weight: .medium, design: .default))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundStyle(.secondary)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
```

### 5. Add allLanguagesPopover Computed Property

**File:** `/Users/mmacbook/develop/Tome/Tome/Views/BookContentView.swift`

Add after the `allPublishersPopover` property (after line 347):

```swift
private var allLanguagesPopover: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("All Languages")
            .font(.system(size: 13, weight: .semibold, design: .default))
            .foregroundStyle(.primary)

        VStack(alignment: .leading, spacing: 8) {
            ForEach(source.languages.sorted(), id: \.self) { lang in
                HStack(spacing: 8) {
                    LanguageBadge(languageCode: lang)
                    Text(LanguageBadge(languageCode: lang).displayName)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 2)
            }
        }
    }
    .padding(16)
    .frame(width: 240)
}
```

### 6. Add Popover Modifier

**File:** `/Users/mmacbook/develop/Tome/Tome/Views/BookContentView.swift`

Add after line 88 (after the `showingAllPublishers` popover):

```swift
.popover(isPresented: $showingAllLanguages) {
    allLanguagesPopover
}
```

### 7. Make LanguageBadge displayName Public

**File:** `/Users/mmacbook/develop/Tome/Tome/Views/Components/LanguageBadge.swift`

Change line 60 from `private var displayName` to:

```swift
var displayName: String {
    Self.languageNames[languageCode] ?? languageCode.uppercased()
}
```

## Summary of Changes

| File | Change Type | Lines |
|------|-------------|-------|
| `AppSettings.swift` | Add extension | After line 189 |
| `BookContentView.swift` | Add state variable | After line 15 |
| `BookContentView.swift` | Replace languages section | Lines 192-207 |
| `BookContentView.swift` | Add computed property | After line 327 |
| `BookContentView.swift` | Add computed property | After line 347 |
| `BookContentView.swift` | Add popover modifier | After line 88 |
| `LanguageBadge.swift` | Change access level | Line 60 |

## Verification

1. **Test with default language supported:**
   - Set default language to English in app settings
   - View a book that has English and other languages (e.g., ["eng", "fre", "spa"])
   - Verify only the English badge is shown

2. **Test with default language not supported:**
   - Set default language to English
   - View a book that only has non-English languages (e.g., ["fre", "spa"])
   - Verify the overflow pattern is used (first language + "+ X more")

3. **Test overflow popover:**
   - Click the "+ X more" button
   - Verify all languages are shown in the popover

4. **Test edge cases:**
   - Book with 1 language: Should show single badge
   - Book with 2 languages (not supporting default): Should show both badges
   - Book with 3+ languages (not supporting default): Should show first badge + "+ X more"
