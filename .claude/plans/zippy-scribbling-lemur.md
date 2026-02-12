# Unified BookContentView Implementation Plan

## Context

Currently, the app has two separate detail views for books:
- **BookDetailView.swift** - Displays user's library books with edit/delete/notes/tags
- **BookDetailsContentView** (in AddBookView.swift) - Displays search results with "Add to Library" button

This creates duplicate code and makes maintenance harder. The user wants a single smart `BookContentView` that adapts based on whether the book comes from search results (BookDocument) or the user's library (Book).

## Recommended Approach

Use a **protocol-based design with an enum wrapper**:
1. Create `BookDisplayable` protocol that both Book and BookDocument conform to
2. Create `BookContentSource` enum that wraps either Book or BookDocument
3. Build unified `BookContentView` that conditionally renders library-specific sections

This approach provides:
- Type-safe access to properties
- Clear separation of concerns
- Easy to extend for future data sources
- Single place to maintain book detail display logic

## Implementation Steps

### Step 1: Create Protocol Layer

**File: `tome/Models/BookDisplayable.swift`** (NEW)

```swift
import Foundation

/// Protocol for types that can be displayed as book details
protocol BookDisplayable {
    var title: String { get }
    var authors: [String] { get }
    var isbn: String? { get }
    var publisher: String? { get }
    var firstPublishYear: Int? { get }
    var pageCount: Int? { get }
    var language: String? { get }
    var subjects: [String] { get }
    var bookDescription: String? { get }
}
```

**File: `tome/Models/BookContentSource.swift`** (NEW)

```swift
import Foundation

/// Enum wrapper for different book content sources
enum BookContentSource: BookDisplayable {
    case library(Book)
    case search(BookDocument)

    // MARK: - BookDisplayable Conformance

    var title: String {
        switch self {
        case .library(let book): return book.title
        case .search(let document): return document.title
        }
    }

    var authors: [String] {
        switch self {
        case .library(let book): return book.authors
        case .search(let document): return document.authorName ?? []
        }
    }

    var isbn: String? {
        switch self {
        case .library(let book): return book.isbn13 ?? book.isbn10
        case .search(let document): return document.isbn13 ?? document.isbn10
        }
    }

    var publisher: String? {
        switch self {
        case .library(let book): return book.publisher
        case .search(let document): return document.publisher?.first
        }
    }

    var firstPublishYear: Int? {
        switch self {
        case .library(let book): return book.firstPublishYear
        case .search(let document): return document.firstPublishYear
        }
    }

    var pageCount: Int? {
        switch self {
        case .library(let book): return book.pageCount
        case .search(let document): return document.numberOfPagesMedian
        }
    }

    var language: String? {
        switch self {
        case .library(let book): return book.language
        case .search(let document): return document.language?.first
        }
    }

    var subjects: [String] {
        switch self {
        case .library(let book): return book.subjects
        case .search(let document): return document.subject ?? []
        }
    }

    var bookDescription: String? {
        switch self {
        case .library(let book): return book.bookDescription
        case .search(let document): return nil // BookDocument doesn't have description
        }
    }

    // MARK: - Computed Properties

    var isLibraryBook: Bool {
        if case .library = self { return true }
        return false
    }

    var coverURL: URL? {
        switch self {
        case .library(let book):
            return book.coverURL
        case .search(let document):
            // Try ISBN first (more reliable), fall back to cover ID
            if let isbn = document.isbn?.first {
                return URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg")
            } else if let coverID = document.coverI {
                return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")
            }
            return nil
        }
    }

    /// For library books: returns the Book instance
    var book: Book? {
        if case .library(let book) = self { return book }
        return nil
    }
}
```

### Step 2: Add Protocol Conformance to Existing Models

**File: `tome/Models/Book.swift`** (MODIFY - add extension at end)

```swift
// Add after line 101:
extension Book: BookDisplayable {
    // Protocol conformance already satisfied by existing properties
}
```

**File: `tome/Models/OpenLibraryModels.swift`** (MODIFY - add extension at end)

```swift
// Add after line 237:
extension BookDocument: BookDisplayable {
    // Protocol conformance already satisfied by existing properties
}
```

### Step 3: Create Unified BookContentView

**File: `tome/Views/BookContentView.swift`** (NEW - ~400 lines)

This view will have:

1. **Properties**:
   - `source: BookContentSource` - The book data to display
   - `onAdd: (() -> Void)?` - Callback for adding to library (search only)
   - `onBack: (() -> Void)?` - Callback for going back (search only)
   - `@Environment(\.modelContext)` - For saving library changes
   - `@State` variables for edit/delete sheets

2. **Sections** (reuse patterns from existing views):
   - `coverSection` - Uses BookCoverView (large), title, authors, year
   - `metadataSection` - Grid showing publisher, pages, language, subjects, ISBN, added date
   - `descriptionSection` - Only if bookDescription exists
   - `readingStatusSection` - LIBRARY ONLY, uses ReadingStatusButtonGroup
   - `notesSection` - LIBRARY ONLY, TextEditor with auto-save
   - `tagsSection` - LIBRARY ONLY, uses TagCloudView
   - `actionSection` - SEARCH ONLY, "Add to Library" button

3. **Toolbar**:
   - Library: Edit/Delete menu
   - Search: "Add to Library" button (or inline button at bottom)

4. **Sheets/Alerts**:
   - Edit sheet (library only)
   - Delete confirmation alert (library only)

Complete implementation should match the structure from BookDetailView but with conditional rendering based on `source.isLibraryBook`.

### Step 4: Update NavigationRootView

**File: `tome/Views/NavigationRootView.swift`** (MODIFY)

Replace detail pane logic (lines 29-109):

```swift
detail: {
    if let book = navigationState.selectedBook, isLibraryDestination(navigationState.selectedDestination) {
        // Library book - show with edit/delete capabilities
        BookContentView(source: .library(book))
    } else if let result = navigationState.selectedSearchResult, navigationState.selectedDestination == .addBooks {
        // Search result - show with "Add to Library" button
        BookContentView(
            source: .search(result),
            onAdd: { addBookFromSearch(result) },
            onBack: {
                withAnimation {
                    navigationState.selectedSearchResult = nil
                }
            }
        )
    } else {
        detailViewForDestination(navigationState.selectedDestination)
    }
}
```

### Step 5: Update AddBookView

**File: `tome/Views/AddBookView.swift`** (MODIFY)

1. **In Search tab** (replace lines 27-42):
   - Replace BookDetailsContentView with BookContentView

2. **In ISBN scan tab** (replace lines 365-378):
   - Replace BookDetailsContentView with BookContentView

3. **Remove old BookDetailsContentView** (delete lines 169-282)

### Step 6: Cleanup

**Delete these files:**
1. `tome/Views/BookDetailView.swift` - Entire file (317 lines), replaced by unified view
2. Lines 169-282 in `tome/Views/AddBookView.swift` - Old BookDetailsContentView implementation

## Files Summary

| Action | File | Purpose |
|---------|-------|---------|
| NEW | `tome/Models/BookDisplayable.swift` | Protocol for book display |
| NEW | `tome/Models/BookContentSource.swift` | Enum wrapper for library/search sources |
| NEW | `tome/Views/BookContentView.swift` | Unified detail view (~400 lines) |
| MODIFY | `tome/Models/Book.swift` | Add BookDisplayable conformance |
| MODIFY | `tome/Models/OpenLibraryModels.swift` | Add BookDisplayable conformance |
| MODIFY | `tome/Views/NavigationRootView.swift` | Update detail pane to use BookContentView |
| MODIFY | `tome/Views/AddBookView.swift` | Replace BookDetailsContentView, add onAdd/onBack |
| DELETE | `tome/Views/BookDetailView.swift` | Replaced by unified view |
| MODIFY | `tome/Views/AddBookView.swift` | Remove old BookDetailsContentView |

## Reusable Components Used

- **BookCoverView** (`tome/Views/Components/BookCoverView.swift`) - Cover image display with caching
- **ReadingStatusButtonGroup** (`tome/Views/Components/ReadingStatusPicker.swift`) - Reading status toggle
- **TagCloudView** (`tome/Views/Components/TagCloudView.swift`) - Tag display and editing

## Verification

After implementation, test these scenarios:

1. **Search Result Flow**:
   - Search for a book
   - Click a result
   - Verify detail pane shows book info
   - Verify "Add to Library" button appears
   - Click "Add to Library"
   - Verify book appears in library with correct data

2. **Library Book Flow**:
   - Select a library book
   - Verify all sections appear (cover, metadata, description, status, notes, tags)
   - Change reading status
   - Edit personal notes
   - Add/remove tags
   - Use Edit button in toolbar
   - Use Delete button in toolbar
   - Verify changes persist

3. **Edge Cases**:
   - Book with no cover
   - Book with no ISBN
   - Book with no description
   - Book with no subjects
   - Book from search vs book in library (different toolbars)

## Implementation Order

1. Create protocol layer files
2. Add protocol conformance to Book and BookDocument
3. Build complete BookContentView
4. Update NavigationRootView
5. Update AddBookView
6. Delete old files
7. Build and test both flows
