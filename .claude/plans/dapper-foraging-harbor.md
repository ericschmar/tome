# Tome: Personal Library Cataloging App - Implementation Plan

## Context

Tome is a personal home library cataloging application built with SwiftUI. The app allows users to build a digital catalog of their physical book collection using data from the OpenLibrary API, with support for manual entry and editing, personal notes, tags, and basic reading status tracking.

**Core Features:**
- Search and add books via OpenLibrary API
- Manual book entry and editing
- View library as a browsable list
- Track reading status (To Read, Reading, Read)
- Add personal notes and custom tags
- CloudKit sync for multi-device access

## Implementation Approach

### Phase 1: Data Model Foundation

**Create comprehensive SwiftData models** to replace the basic `Item` model:

1. **New Models to Create (`tome/Models/` directory):**
   - `Book.swift` - Primary book model with OpenLibrary metadata
   - `ReadingStatus.swift` - Enum for reading status
   - `Tag.swift` - Tag model for custom categorization
   - `OpenLibraryModels.swift` - API response models

2. **Book Model Structure:**
```swift
@Model
final class Book {
    var id: UUID
    var title: String
    var authors: [String]
    var isbn10: String?
    var isbn13: String?
    var coverID: Int?
    var coverImageData: Data?
    var firstPublishYear: Int?
    var description: String?
    var publisher: String?
    var pageCount: Int?
    var language: String?
    var subjects: [String]
    var openLibraryKey: String?
    var personalNotes: String
    var readingStatus: ReadingStatus
    var dateAdded: Date
    var tags: [Tag]
    var sortOrder: Int

    // Computed property for cover URL
    var coverURL: URL? {
        guard let coverID = coverID else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")
    }
}
```

### Phase 2: OpenLibrary Service Layer

**Create API service** for OpenLibrary integration:

1. **Files to Create (`tome/Services/` directory):**
   - `OpenLibraryService.swift` - Main API service
   - `OpenLibraryEndpoints.swift` - API endpoint definitions

2. **Key Service Methods:**
   - `searchBooks(query:)` - Search via OpenLibrary Search API
   - `fetchBookDetails(openLibraryKey:)` - Get detailed book info
   - `fetchCoverImage(coverID:)` - Download and cache cover images
   - `lookupByISBN(isbn:)` - ISBN-based lookup

3. **Response Models:**
   - `SearchResponse` - Search API response wrapper
   - `BookDocument` - Individual book in search results
   - `WorkDetails` - Detailed work information

### Phase 3: User Interface

**Create SwiftUI views** for the core features:

#### View Structure (`tome/Views/` directory):

1. **Library List View** - `LibraryListView.swift`
   - Grid/list toggle for displaying books
   - Filter by reading status and tags
   - Sort options (title, author, date added)
   - Search functionality
   - Empty state with "Add your first book" CTA

2. **Book Detail View** - `BookDetailView.swift`
   - Large cover image
   - Full metadata display
   - Reading status picker
   - Personal notes editor
   - Tag management
   - Edit button

3. **Add Book View** - `AddBookView.swift`
   - Tab-based interface:
     - **Search Tab**: OpenLibrary search with results list
     - **Manual Entry Tab**: Form fields for manual input
     - **ISBN Scan Tab**: Barcode scanner (future enhancement)
   - Book preview card before adding

4. **Edit Book View** - `EditBookView.swift`
   - Reusable form with all editable fields
   - Fetch updated data from OpenLibrary option
   - Save/Cancel actions

5. **Components (`tome/Views/Components/`):**
   - `BookCard.swift` - Reusable book display card
   - `BookCoverView.swift` - Async image loading with placeholder
   - `ReadingStatusPicker.swift` - Status selection UI
   - `TagCloudView.swift` - Visual tag display
   - `SearchResultRow.swift` - OpenLibrary search result

### Phase 4: Navigation & App Structure

**Update app structure:**

1. **Modify `tomeApp.swift`:**
   - Update SwiftData schema to include new models
   - Configure model container with migration strategy

2. **Create `NavigationRootView.swift`:**
   - TabView structure:
     - Library tab (main list)
     - Search/Add tab
     - Settings tab (future)

3. **Update `ContentView.swift`:**
   - Rename/repurpose as `LibraryListView`

### Phase 5: Image Caching & Performance

**Implement image handling:**

1. **Create `ImageCacheService.swift`** in Services directory:
   - Memory cache with NSCache
   - Disk cache for persistent storage
   - Async image loading with SwiftUI integration

2. **Cover Image Handling:**
   - Store frequently accessed covers locally as Data
   - Lazy loading for library grid view
   - Proper memory management for large lists

### Phase 6: State Management

**Create view models** using `@Observable`:

1. **`LibraryViewModel.swift`** - Manage library state
2. **`BookSearchViewModel.swift`** - Handle OpenLibrary search
3. **`BookDetailViewModel.swift`** - Single book operations

## File Structure

```
tome/
├── tomeApp.swift                    [MODIFY] - Update schema
├── Models/
│   ├── Book.swift                   [CREATE] - Main book model
│   ├── ReadingStatus.swift          [CREATE] - Status enum
│   ├── Tag.swift                    [CREATE] - Tag model
│   └── OpenLibraryModels.swift      [CREATE] - API response models
├── Services/
│   ├── OpenLibraryService.swift     [CREATE] - API client
│   ├── OpenLibraryEndpoints.swift   [CREATE] - API endpoints
│   └── ImageCacheService.swift      [CREATE] - Image caching
├── Views/
│   ├── LibraryListView.swift        [CREATE] - Main library view
│   ├── BookDetailView.swift         [CREATE] - Book detail
│   ├── AddBookView.swift            [CREATE] - Add book interface
│   ├── EditBookView.swift           [CREATE] - Edit book form
│   └── Components/
│       ├── BookCard.swift           [CREATE] - Book card component
│       ├── BookCoverView.swift      [CREATE] - Cover image view
│       ├── ReadingStatusPicker.swift [CREATE] - Status picker
│       ├── TagCloudView.swift       [CREATE] - Tag display
│       └── SearchResultRow.swift    [CREATE] - Search result
├── ViewModels/
│   ├── LibraryViewModel.swift       [CREATE] - Library state
│   ├── BookSearchViewModel.swift    [CREATE] - Search state
│   └── BookDetailViewModel.swift    [CREATE] - Book state
└── [DELETE] Item.swift              [DELETE] - Remove template model
```

## OpenLibrary API Integration Details

**Search Endpoint:**
```
https://openlibrary.org/search.json?q={query}&fields=key,title,author_name,isbn,cover_i,first_publish_year,language,publisher,number_of_pages_median,subject
```

**Works Detail Endpoint:**
```
https://openlibrary.org/works/{key}.json
```

**Cover Image URL Pattern:**
```
https://covers.openlibrary.org/b/id/{cover_id}-{size}.jpg
// Sizes: S (small), M (medium), L (large)
```

**Rate Limiting:**
- Covers API: 100 requests per 5 minutes
- Implement request throttling
- Cache all responses aggressively

## Key Implementation Considerations

1. **SwiftData Relationships:** Use `@Relationship` for Book-to-Tag many-to-many connection
2. **CloudKit Sync:** Models already configured - ensure proper CloudKit container setup
3. **Error Handling:** Graceful degradation when OpenLibrary is unavailable
4. **Performance:** Lazy loading for large libraries, pagination in search results
5. **Accessibility:** Support VoiceOver, Dynamic Type, and keyboard navigation
6. **Platform Adaptations:** iPad-specific layouts (sidebar + detail), macOS window management

## Verification Steps

**Testing Checklist:**

1. **Add Books:**
   - [ ] Search OpenLibrary and add a book
   - [ ] Add a book manually with all fields
   - [ ] Add a book via ISBN lookup
   - [ ] Verify cover image loads correctly

2. **View Library:**
   - [ ] Display books in grid view
   - [ ] Display books in list view
   - [ ] Filter by reading status
   - [ ] Filter by tags
   - [ ] Sort by different criteria
   - [ ] Search local library

3. **Edit Books:**
   - [ ] Edit book metadata
   - [ ] Change reading status
   - [ ] Add/edit personal notes
   - [ ] Add/remove tags
   - [ ] Update cover image

4. **Persistence:**
   - [ ] Verify data persists across app restarts
   - [ ] Test CloudKit sync (if container configured)

5. **Edge Cases:**
   - [ ] Handle network errors gracefully
   - [ ] Handle empty library state
   - [ ] Handle books without covers
   - [ ] Handle special characters in search
   - [ ] Large library performance (100+ books)

**Run on both platforms:**
- iOS Simulator (iPhone and iPad)
- Mac (built for Mac)
