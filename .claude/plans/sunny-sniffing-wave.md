# Semantic Search Migration Plan

## Context

**Problem:** Current book search uses fuzzy string matching (Levenshtein distance) which only finds books based on keyword similarity. Users searching for concepts (e.g., "books about artificial intelligence") won't find relevant books unless those exact words appear in titles/authors/subjects.

**Solution:** Migrate to **SimilaritySearchKit** - a Swift library that provides semantic search using on-device text embeddings. This enables finding books based on meaning rather than just keyword matching.

**Model Choice:** Use Apple's built-in `NativeEmbeddings()` (0 MB size) instead of downloading external models. This leverages the NaturalLanguage framework already included in iOS/macOS, avoiding app bloat.

**Target Impact:**
- Search "machine learning" → finds "AI Revolution" even without those exact words
- Search "cooking" → finds "The Joy of Cooking" and "Mastering the Art of French Cooking"
- Maintain instant ISBN exact matching for known lookups

## Recommended Approach: Hybrid Search

**Strategy:** Combine semantic search with ISBN exact matching

```
┌─────────────────────────────────────────────────┐
│              BookSearchService                  │
│     (Maintains existing API surface)            │
└────────────────────┬────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│ SemanticSearch   │    │  ISBN Index      │
│ (SimilarityKit)  │    │  (Exact Match)    │
│  - Title         │    │  - ISBN10/13      │
│  - Authors       │    │  - Instant        │
│  - Description   │    └──────────────────┘
│  - Subjects      │              │
└──────────────────┘              │
         │                       │
         └───────────┬───────────┘
                     ▼
              Merged Results
              (ISBN boosted)
```

**Why Hybrid?**
- ISBN searches are exact and instant (no embedding generation needed)
- Semantic search provides conceptual understanding
- Fallback if semantic model fails to load
- Best of both: accuracy + speed

## Implementation Steps

### Step 1: Add SimilaritySearchKit Package

**File:** `Tome.xcodeproj/project.pbxproj`

1. In Xcode: File → Add Package Dependencies
2. URL: `https://github.com/ZachNagengast/similarity-search-kit.git`
3. Select product:
   - `SimilaritySearchKit` only (no model downloads needed)

### Step 2: Create Semantic Search Wrapper

**New File:** `/Users/mmacbook/develop/Tome/Tome/Services/SemanticBookSearch.swift`

```swift
import Foundation
import SimilaritySearchKit
import SwiftData

/// Wrapper around SimilaritySearchKit for semantic book search
@MainActor
final class SemanticBookSearch {
    private var index: SimilarityIndex?
    private let model = NativeEmbeddings() // Built-in, 0 MB, uses Apple's NaturalLanguage framework

    /// Initialize the semantic search index
    func initialize() async throws {
        index = await SimilarityIndex(
            model: model,
            metric: CosineSimilarity()
        )
    }

    /// Add a book to the semantic index
    func indexBook(_ book: Book) async {
        let searchableText = composeSearchableText(from: book)
        await index?.addItem(
            id: book.id.uuidString,
            text: searchableText,
            metadata: [
                "title": book.title,
                "authors": book.authors.joined(separator: ", "),
                "year": book.firstPublishYear?.description ?? ""
            ]
        )
    }

    /// Remove a book from the index
    func removeBook(id: UUID) async {
        await index?.delete(id: id.uuidString)
    }

    /// Search for books using semantic similarity
    func search(_ query: String) async -> [(id: UUID, score: Double)] {
        guard let index = index else { return [] }
        let results = await index.search(query)
        return results.compactMap { result in
            guard let uuid = UUID(uuidString: result.id) else { return nil }
            return (id: uuid, score: Double(result.score))
        }
    }

    /// Clear all indexed books
    func clearIndex() async {
        index = await SimilarityIndex(model: model, metric: CosineSimilarity())
    }

    /// Compose searchable text from book fields
    private func composeSearchableText(from book: Book) -> String {
        var parts: [String] = []

        // Title (primary search field)
        parts.append("Title: \(book.title)")

        // Authors
        if !book.authors.isEmpty {
            parts.append("By: \(book.authors.joined(separator: ", "))")
        }

        // Subjects
        if !book.subjects.isEmpty {
            parts.append("Subjects: \(book.subjects.joined(separator: ", "))")
        }

        // Description (semantic understanding)
        if let description = book.bookDescription {
            // Limit description to avoid token limit
            parts.append("Description: \(description.prefix(500))")
        }

        // Publishers
        if !book.publishers.isEmpty {
            parts.append("Publisher: \(book.publishers.joined(separator: ", "))")
        }

        return parts.joined(separator: "\n")
    }
}
```

### Step 3: Refactor BookSearchService

**File:** `/Users/mmacbook/develop/Tome/Tome/Services/BookSearchService.swift`

**Changes:**
1. Add `SemanticBookSearch` instance
2. Add async initialization for model loading
3. Modify `search()` to use hybrid approach (semantic + ISBN)
4. Update `rebuildIndex()` to handle embedding generation
5. Add model loading state

**Key modifications:**

```swift
@MainActor
@Observable
final class BookSearchService {
    static let shared = BookSearchService()

    private let semanticSearch = SemanticBookSearch()
    private let isbnIndex: [String: UUID] = [:] // Simplified ISBN-only index
    private let persistenceManager = SearchIndexPersistence()

    var isIndexing = false
    var indexProgress: Double = 0.0
    var lastIndexedDate: Date?
    var isModelLoading = false // NEW: Track model loading

    private init() {
        Task {
            await initialize()
        }
    }

    private func initialize() async {
        isModelLoading = true
        defer { isModelLoading = false }

        do {
            try await semanticSearch.initialize()
            await loadPersistedIndex()
        } catch {
            print("⚠️ Failed to initialize semantic search: \(error)")
        }
    }

    func search(query: String, in modelContext: ModelContext) -> [Book] {
        // Check ISBN first (instant)
        if let isbnResult = searchISBN(query, in: modelContext) {
            return [isbnResult]
        }

        // Use semantic search (async)
        // Note: This becomes async - will need to update LibraryViewModel
        Task {
            let semanticResults = await semanticSearch.search(query)
            return fetchBooks(ids: semanticResults.map { $0.id }, in: modelContext)
        }

        // For now, return empty or cache
        return []
    }

    func rebuildIndex(from modelContext: ModelContext) async throws {
        isIndexing = true
        indexProgress = 0.0

        defer {
            isIndexing = false
        }

        await semanticSearch.clearIndex()

        let descriptor = FetchDescriptor<Book>()
        let books = try modelContext.fetch(descriptor)

        let total = books.count
        guard total > 0 else { return }

        for (index, book) in books.enumerated() {
            await semanticSearch.indexBook(book)

            indexProgress = Double(index + 1) / Double(total)

            // Yield more frequently due to slower embedding generation
            if index % 5 == 0 {
                await Task.yield()
            }
        }

        lastIndexedDate = Date()
        await persistIndex()
    }
}
```

**Important:** The `search()` method now needs to be async. This requires updating `LibraryViewModel.applyFiltersAndSort()`.

### Step 4: Update LibraryViewModel for Async Search

**File:** `/Users/mmacbook/develop/Tome/Tome/ViewModels/LibraryViewModel.swift`

**Location:** Lines 130-136 (current `applyFiltersAndSort` method)

**Change from:**
```swift
func applyFiltersAndSort() {
    filteredBooks = books

    if !searchText.isEmpty {
        filteredBooks = searchService.search(query: searchText, in: modelContext)
    }
    // ... rest of filtering
}
```

**Change to:**
```swift
func applyFiltersAndSort() {
    filteredBooks = books

    if !searchText.isEmpty {
        // Search is now async
        Task {
            let results = await searchService.search(query: searchText, in: modelContext)
            await MainActor.run {
                self.filteredBooks = results
                // Re-apply other filters
                self.applyOtherFilters(to: &self.filteredBooks)
            }
        }
    } else {
        // ... rest of filtering
    }
}
```

### Step 5: Add Search Debounce

**File:** `/Users/mmacbook/develop/Tome/Tome/ViewModels/LibraryViewModel.swift`

To avoid excessive embedding generation while typing:

```swift
import Combine

@MainActor
@Observable
final class LibraryViewModel {
    // ... existing properties

    private var debounceTask: Task<Void, Never>?

    func applyFiltersAndSort() {
        // Cancel previous search
        debounceTask?.cancel()

        // Debounce by 300ms
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms
            } catch {
                return // Cancelled
            }

            await performSearch()
        }
    }

    private func performSearch() async {
        if !searchText.isEmpty {
            let results = await searchService.search(query: searchText, in: modelContext)
            self.filteredBooks = results
            self.applyOtherFilters(to: &self.filteredBooks)
        }
    }
}
```

### Step 6: Update Index Persistence

**File:** `/Users/mmacbook/develop/Tome/Tome/Services/BookSearchService.swift`

**Note:** SimilaritySearchKit doesn't provide built-in persistence. Options:
1. Rebuild index on app launch (current approach, works for small libraries)
2. Serialize embeddings to disk (complex, consider in future optimization)
3. Hybrid: persist book IDs, rebuild embeddings in background

**Recommendation:** Keep current approach (rebuild on launch) but show progress:
- Rebuild 500 books in ~10 seconds with progress indicator
- Cache results to avoid re-searching same queries

## Critical Files

### Files to Modify

1. **`Tome/Services/BookSearchService.swift`**
   - Add `SemanticBookSearch` instance
   - Make `search()` async
   - Update `rebuildIndex()` for embedding generation
   - Add `isModelLoading` state

2. **`Tome/ViewModels/LibraryViewModel.swift`**
   - Lines 130-136: Update `applyFiltersAndSort()` for async search
   - Add 300ms debounce to reduce embedding generation
   - Handle loading state during search

3. **`Tome.xcodeproj/project.pbxproj`**
   - Add SimilaritySearchKit package dependency

### Files to Create

4. **`Tome/Services/SemanticBookSearch.swift`** (NEW)
   - Wrapper around SimilaritySearchKit
   - Text composition from book fields
   - Metadata storage for filtering

### Files to Remove/Simplify

5. **`Tome/Services/BookSearchIndex.swift`**
   - Simplify to ISBN-only index (~200 lines removed)
   - Remove fuzzy matching logic (handled by semantic search)
   - Keep ISBN exact match for instant lookups

## Existing Functions to Reuse

- **`BookSearchService.indexBook()`** (line 62) - Keep interface, update implementation
- **`BookSearchService.rebuildIndex()`** (line 82) - Keep progress tracking, add async embedding
- **`BookSearchService.removeBook()`** (line 72) - Keep interface, update implementation
- **`SearchIndexPersistence`** (line 192) - Reuse for persisting book IDs
- **`IndexStats`** (line 174) - Keep for UI statistics

## Performance Considerations

| Metric | Current (Fuzzy) | With Semantic | Impact |
|--------|-----------------|---------------|--------|
| Search latency | ~10ms | ~50-100ms | 5-10x slower (acceptable) |
| Indexing speed | ~1000 books/sec | ~50-100 books/sec | 10-20x slower |
| Model load time | N/A | ~100ms | One-time cost on launch (built-in) |
| App size | +0 MB | +0 MB | NativeEmbeddings uses system framework |
| Memory | ~1 MB | ~10 MB | NaturalLanguage framework (shared system) |

**Mitigations:**
- NativeEmbeddings is faster than downloaded models (~100ms load vs ~500ms)
- Search debounce (300ms) to reduce embedding generation
- ISBN exact match remains instant
- Progress indicator during indexing
- Lazy model loading (on first search, not app launch)
- Zero app size impact (uses system framework)

## Verification

### Manual Testing

1. **Install Package:** Build project with SimilaritySearchKit dependency
2. **Test Semantic Search:**
   - Search "artificial intelligence" → Should find books about AI even without exact words
   - Search "cooking" → Should find cookbooks
   - Search ISBN → Should be instant and exact
3. **Test Performance:**
   - Search 1000-book library <100ms
   - Index 500 books in <10 seconds
4. **Test Fallback:**
   - Disable semantic search → Should fall back to ISBN-only
   - Model load failure → Should show error gracefully

### Automated Testing

**New File:** `/Users/mmacbook/develop/Tome/TomeTests/SemanticSearchTests.swift`

```swift
import XCTest
import SimilaritySearchKit
@testable import Tome

final class SemanticSearchTests: XCTestCase {
    func testSemanticSearchConceptMatch() {
        // Search "machine learning" finds "AI Revolution"
    }

    func testISBNExactMatch() {
        // ISBN search is instant
    }

    func testSearchPerformance() {
        // Measure: search <100ms for 1000 books
    }

    func testIndexingPerformance() {
        // Measure: index 100 books in <2 seconds
    }
}
```

### Integration Checklist

- [ ] SimilaritySearchKit package added
- [ ] `SemanticBookSearch.swift` created
- [ ] `BookSearchService` refactored for async search
- [ ] `LibraryViewModel.applyFiltersAndSort()` updated with debounce
- [ ] ISBN index simplified (removed fuzzy logic)
- [ ] Progress indicator shows during model loading
- [ ] Manual testing completed with real library
- [ ] Performance benchmarks met
- [ ] Error handling tested (model load failure)

## Future Enhancements

After successful migration:
1. **Query Caching:** Cache top 10 recent searches
2. **Background Indexing:** Index books during app idle time
3. **Persistent Embeddings:** Save embeddings to disk (faster startup)
4. **Faceted Search:** Filter by year, language, publisher post-search
5. **Search Suggestions:** Autocomplete based on library
6. **Personalization:** Learn from user's search history

## Summary

This migration replaces fuzzy string matching with semantic understanding while maintaining instant ISBN lookup. The hybrid approach provides:
- ✅ Better search relevance (semantic vs keyword)
- ✅ Zero app size increase (uses built-in NaturalLanguage framework)
- ✅ Graceful degradation (ISBN fallback)
- ✅ Backward compatible (same API surface)
- ⚠️ Trade-off: 5-10x slower search (10ms → 50-100ms, acceptable for semantic search)

**Why NativeEmbeddings over MiniLMAll:**
- Size: 0 MB vs 46 MB (built into iOS/macOS)
- Load time: ~100ms vs ~500ms (system framework optimization)
- Privacy: Same on-device processing
- Trade-off: Slightly less accurate than HuggingFace models, but still significantly better than keyword matching

**Estimated effort:** 2-3 days implementation + 1 day testing
