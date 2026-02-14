import Foundation
import SwiftData
import Observation

/// Service for managing book search with persistent index
@MainActor
@Observable
final class BookSearchService {
    static let shared = BookSearchService()
    
    private let searchIndex = BookSearchIndex()
    private let persistenceManager = SearchIndexPersistence()
    
    var isIndexing = false
    var indexProgress: Double = 0.0
    var lastIndexedDate: Date?
    
    private init() {
        // Load persisted index on init
        Task {
            await loadPersistedIndex()
        }
    }
    
    // MARK: - Public API
    
    /// Search for books in the library, returning actual Book objects
    func search(query: String, in modelContext: ModelContext) -> [Book] {
        let searchResults = searchIndex.search(query: query)

        print(searchResults)
        // Extract book IDs from search results
        let bookIds = searchResults.map { $0.book.id }

        // Fetch actual Book objects from SwiftData
        guard !bookIds.isEmpty else { return [] }

        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate<Book> { book in
                bookIds.contains(book.id)
            }
        )

        let fetchedBooks: [Book]
        do {
            fetchedBooks = try modelContext.fetch(descriptor)
        } catch {
            print("⚠️ Failed to fetch books from search results: \(error)")
            return []
        }

        // Sort results according to search ranking
        let idToIndex = Dictionary(uniqueKeysWithValues: bookIds.enumerated().map { ($1, $0) })
        return fetchedBooks.sorted { book1, book2 in
            let index1 = idToIndex[book1.id] ?? Int.max
            let index2 = idToIndex[book2.id] ?? Int.max
            return index1 < index2
        }
    }
    
    /// Add a book to the search index
    func indexBook(_ book: Book) {
        searchIndex.indexBook(book)
        
        // Persist in background
        Task {
            await persistIndex()
        }
    }
    
    /// Remove a book from the search index
    func removeBook(id: UUID) {
        searchIndex.removeBook(id)
        
        // Persist in background
        Task {
            await persistIndex()
        }
    }
    
    /// Rebuild the entire search index from the model context
    func rebuildIndex(from modelContext: ModelContext) async throws {
        isIndexing = true
        indexProgress = 0.0
        
        defer {
            isIndexing = false
        }
        
        // Clear existing index
        searchIndex.clearIndex()
        
        // Fetch all books
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        let books = try modelContext.fetch(descriptor)
        
        let total = books.count
        guard total > 0 else {
            lastIndexedDate = Date()
            await persistIndex()
            return
        }
        
        // Index books with progress updates
        for (index, book) in books.enumerated() {
            searchIndex.indexBook(book)
            
            // Update progress
            indexProgress = Double(index + 1) / Double(total)
            
            // Yield periodically to keep UI responsive
            if index % 10 == 0 {
                await Task.yield()
            }
        }
        
        lastIndexedDate = Date()
        indexProgress = 1.0
        
        // Persist the index
        await persistIndex()
    }
    
    /// Check if index needs rebuilding (e.g., if book count doesn't match)
    func needsReindexing(modelContext: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<Book>()
        let bookCount = try modelContext.fetchCount(descriptor)
        
        return searchIndex.count != bookCount
    }
    
    /// Get current index statistics
    var indexStats: IndexStats {
        IndexStats(
            bookCount: searchIndex.count,
            lastIndexedDate: lastIndexedDate
        )
    }
    
    // MARK: - Persistence
    
    private func persistIndex() async {
        // Convert search index to persistable format
        let bookIds = searchIndex.indexedBookIds
        let metadata = SearchIndexMetadata(
            bookIds: Array(bookIds),
            lastUpdated: Date(),
            version: 1
        )
        
        await persistenceManager.save(metadata: metadata)
    }
    
    private func loadPersistedIndex() async {
        guard let metadata = await persistenceManager.load() else {
            return
        }
        
        lastIndexedDate = metadata.lastUpdated
        // Note: We store metadata but rebuild index on startup for simplicity
        // In a production app, you might want to serialize the entire index
    }
    
    /// Clear persisted index data
    func clearPersistedData() async {
        await persistenceManager.clear()
        searchIndex.clearIndex()
        lastIndexedDate = nil
    }
}

// MARK: - Index Stats

struct IndexStats {
    let bookCount: Int
    let lastIndexedDate: Date?
    
    var formattedLastIndexed: String {
        guard let date = lastIndexedDate else {
            return "Never indexed"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Indexed \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

// MARK: - Search Index Persistence

/// Manages persistence of search index metadata
actor SearchIndexPersistence {
    private let fileURL: URL
    
    init() {
        // Store in Application Support directory
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        let bundleId = Bundle.main.bundleIdentifier ?? "com.app.library"
        let appDirectory = appSupport.appendingPathComponent(bundleId, isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true
        )
        
        self.fileURL = appDirectory.appendingPathComponent("search_index.json")
    }
    
    func save(metadata: SearchIndexMetadata) async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metadata)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("⚠️ Failed to save search index metadata: \(error)")
        }
    }
    
    func load() async -> SearchIndexMetadata? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SearchIndexMetadata.self, from: data)
        } catch {
            print("⚠️ Failed to load search index metadata: \(error)")
            return nil
        }
    }
    
    func clear() async {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - Search Index Metadata

struct SearchIndexMetadata: Codable {
    let bookIds: [UUID]
    let lastUpdated: Date
    let version: Int
}
