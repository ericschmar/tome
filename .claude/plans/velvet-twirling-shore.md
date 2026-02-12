# BookContentView Visual Redesign

## Context

The BookContentView needs visual improvements to better highlight book information, display multiple publishers and languages properly, and allow users to select and copy all textual information.

**Current issues:**
- Cover image is too large (200px) and dominates the layout
- Title, author, and publish date are underwhelming and don't catch the eye
- Publishers and languages are shown as single values, but search results have arrays
- Languages are plain text - would be better as colored badges
- Text cannot be easily selected/copied by users

## Implementation Plan

### Phase 1: Update Data Models for Arrays

**File: `tome/Models/BookDisplayable.swift`**
Add new protocol properties for arrays:

```swift
protocol BookDisplayable {
    // existing properties...
    var publishers: [String] { get }  // NEW
    var languages: [String] { get }   // NEW
}
```

**File: `tome/Models/BookContentSource.swift`**
Implement the new array properties:
- For library books (single value): wrap in array or return empty
- For search results: return the full arrays from BookDocument

```swift
var publishers: [String] {
    switch self {
    case .library(let book):
        return book.publisher.map { [$0] } ?? []
    case .search(let document):
        return document.publisher ?? []
    }
}

var languages: [String] {
    switch self {
    case .library(let book):
        return book.language.map { [$0] } ?? []
    case .search(let document):
        return document.language ?? []
    }
}
```

---

### Phase 2: Create LanguageBadge Component

**File: `tome/Views/Components/LanguageBadge.swift`** (NEW)

Create a reusable language badge component:
- Similar to `TagChip` but simpler (no edit mode)
- Capsule shape with mild rounded edges
- Auto-assigned colors from pleasing palette based on language code
- Use color palette: `["#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#30B0C7", "#32ADE6", "#8E8E93"]`
- Color selection: hash the language string to pick consistent color
- Optionally display full language name (map "eng" → "English", "fre" → "French", etc.)

```swift
struct LanguageBadge: View {
    let languageCode: String
    let color: Color

    init(languageCode: String) {
        self.languageCode = languageCode
        self.color = Self.color(for: languageCode)
    }

    var body: some View {
        Text(displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private static func color(for code: String) -> Color {
        // Hash-based color selection from palette
    }
}
```

---

### Phase 3: Redesign BookContentView

**File: `tome/Views/BookContentView.swift`**

#### 3.1 Update Cover Section (lines 119-149)
- Change `size: .large` to `size: .medium` (line 126)
- Improve title, author, date typography:

```swift
Text(source.title)
    .font(.title)           // Larger (was .title2)
    .fontWeight(.bold)      // Keep bold

Text(displayAuthors)
    .font(.title3)          // Larger (was .subheadline)
    .foregroundStyle(.primary)  // More prominent

if source.firstPublishYear != nil {
    Text("Published \(displayYear)")
        .font(.subheadline)     // Larger (was .caption)
        .foregroundStyle(.secondary)  // More visible
}
```

- Add `.textSelection(.enabled)` to all three text elements

#### 3.2 Update Metadata Section (lines 151-208)
Replace current publisher/language grid rows with new expandable sections:

**Publishers:**
- If 1-3 publishers: show all
- If 4+ publishers: show first 3 with "and X more..." link
- Click link to expand/collapse full list
- Use `@State private var isPublishersExpanded = false`

**Languages:**
- Replace single language text with flowing badge layout
- Use `LanguageBadge` components
- Add `.textSelection(.enabled)` where appropriate

```swift
// Publishers section
if !source.publishers.isEmpty {
    VStack(alignment: .leading, spacing: 8) {
        Text("Publishers")
            .font(.headline)

        ForEach(visiblePublishers, id: \.self) { publisher in
            Text(publisher)
                .textSelection(.enabled)
        }

        if source.publishers.count > 3 {
            Button(action: { isPublishersExpanded.toggle() }) {
                Text(isPublishersExpanded ? "Show less" : "and \(source.publishers.count - 3) more...")
                    .font(.caption)
                    .foregroundStyle(.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

// Languages section with badges
if !source.languages.isEmpty {
    VStack(alignment: .leading, spacing: 8) {
        Text("Languages")
            .font(.headline)

        FlowingLayout {
            ForEach(source.languages, id: \.self) { lang in
                LanguageBadge(languageCode: lang)
                    .textSelection(.enabled)
            }
        }
    }
}
```

**Add `.textSelection(.enabled)` to ALL text elements:**
- Title, authors, publish date
- Publisher names
- Subjects
- ISBN
- Page count
- Date added
- Book description

---

### Phase 4: Create FlowingLayout Helper

**File: `tome/Views/Components/FlowingLayout.swift`** (NEW)

Simple flowing layout for language badges (similar to TagCloudView but simpler):

```swift
struct FlowingLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Calculate flowing layout size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Place views in flowing pattern
    }
}
```

Or reuse the existing TagCloudView's layout pattern with a simpler wrapper.

---

### Phase 5: Update Book Model for Arrays

**File: `tome/Models/Book.swift`**

Migrate from single values to arrays to support multiple publishers and languages:

```swift
// OLD (remove):
var publisher: String?
var language: String?

// NEW (add):
var publishers: [String]
var languages: [String]
```

**Migration in BookContentSource:**
- For library books: return the arrays directly
- For search results: return arrays or empty array

**Updated BookContentSource implementation:**
```swift
var publishers: [String] {
    switch self {
    case .library(let book): return book.publishers
    case .search(let document): return document.publisher ?? []
    }
}

var languages: [String] {
    switch self {
    case .library(let book): return book.languages
    case .search(let document): return document.language ?? []
    }
}
```

**Note:** This change will require updating:
- `Book.init()` to accept arrays with default empty values
- `BookDocument.toBook()` to map first values to arrays
- EditBookView form to handle arrays (or keep as single-value editor that creates single-item arrays)

---

## Files to Modify

1. **tome/Models/BookDisplayable.swift** - Add `publishers` and `languages` array properties
2. **tome/Models/Book.swift** - Change `publisher`/`language` to `publishers`/`languages` arrays
3. **tome/Models/BookContentSource.swift** - Implement array properties for both book types
4. **tome/Models/OpenLibraryModels.swift** - Update `BookDocument.toBook()` to convert to arrays
5. **tome/Views/BookContentView.swift** - Redesign cover section, metadata section, add text selection
6. **tome/Views/EditBookView.swift** - Update publisher/language form fields for arrays
7. **tome/Views/Components/LanguageBadge.swift** - NEW: Language badge with color palette
8. **tome/Views/Components/FlowingLayout.swift** - NEW: Simple flowing layout for badges (optional, can use alternative)

---

## Verification

1. Build the project and verify no compilation errors
2. Test with search results that have:
   - Single publisher/language
   - Multiple publishers (3 or fewer)
   - Multiple publishers (4 or more) - verify expand/collapse works
   - Multiple languages - verify badges display with different colors
3. Test with library books (single publisher/language values)
4. Verify all text is selectable and copyable
5. Check visual hierarchy - cover is smaller, title/author/date are more prominent
6. Test on both light and dark mode to ensure badge colors work well

---

## Color Palette for Language Badges

Reuse existing TagColorPicker palette:
```swift
let languageColors: [String] = [
    "#007AFF",  // Blue
    "#5856D6",  // Purple
    "#AF52DE",  // Pink
    "#FF2D55",  // Red-pink
    "#FF3B30",  // Red
    "#FF9500",  // Orange
    "#FFCC00",  // Yellow
    "#34C759",  // Green
    "#30B0C7",  // Teal
    "#32ADE6",  // Cyan
    "#8E8E93"   // Gray
]
```

Hash the language code string to select a consistent color for each language.

---

## Notes

- **Book model migration:** Changing `publisher`/`language` from single strings to arrays
  - Existing data will need migration: single value → single-item array
  - EditBookView form may need updates to handle array input
  - Or keep form simple: single TextField that creates single-item array
- Search results already have arrays in BookDocument, so they'll display naturally
- The expandable "..." pattern for publishers is a common UI pattern
- Flowing layout for badges can reuse the TagCloudView's geometry reader pattern or use SwiftUI's Layout protocol
- Text selection uses `.textSelection(.enabled)` modifier (available iOS 15+, macOS 12+)
