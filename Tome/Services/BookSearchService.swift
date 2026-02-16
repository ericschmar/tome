import Foundation
import SwiftData
import Observation

/// Service for managing book search with persistent index
@MainActor
@Observable
final class BookSearchService {
    static let shared = BookSearchService()

    private let semanticSearch = SemanticBookSearch()
    private let persistenceManager = SearchIndexPersistence()

    var isIndexing = false
    var indexProgress: Double = 0.0
    var lastIndexedDate: Date?
    var isModelLoading = false

    private init() {
        // Initialize semantic search on init
        Task {
            await initialize()
        }
    }

    private func initialize() async {
        isModelLoading = true
        defer { isModelLoading = false }

        do {
            // Try to load persisted index
            let lastSaved = await semanticSearch.persistenceManager.lastSavedDate()

            // If we have a saved index, try to load it
            if let saved = lastSaved {
                print("📂 Found saved index from \(saved)")
                try await semanticSearch.initialize(loadFrom: .loadIfAvailable)
                lastIndexedDate = saved
            } else {
                print("📂 No saved index found")
                try await semanticSearch.initialize(loadFrom: .forceRebuild)
            }
        } catch {
            print("⚠️ Failed to initialize semantic search: \(error)")
        }
    }
    
    // MARK: - Public API

    /// Search for books in the library, returning actual Book objects
    func search(query: String, in modelContext: ModelContext) async -> [Book] {
        // Check ISBN first (instant exact match)
        if let isbnResult = searchISBN(query: query, in: modelContext) {
            return [isbnResult]
        }

        // Use semantic search
        let semanticResults = await semanticSearch.search(query)

        guard !semanticResults.isEmpty else { return [] }

        // Fetch actual Book objects from SwiftData
        let bookIds = semanticResults.map { $0.id }

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

        // Sort results according to semantic search ranking
        let idToScore = Dictionary(uniqueKeysWithValues: semanticResults.map { ($0.id, $0.score) })
        return fetchedBooks.sorted { book1, book2 in
            let score1 = idToScore[book1.id] ?? 0
            let score2 = idToScore[book2.id] ?? 0
            return score1 > score2
        }
    }

    /// Search by ISBN for instant exact match
    private func searchISBN(query: String, in modelContext: ModelContext) -> Book? {
        let normalizedQuery = query.normalizedForSearch()

        // Fetch all books and filter in memory since normalizedForSearch() 
        // is not supported in predicates
        let descriptor = FetchDescriptor<Book>()

        let results: [Book]
        do {
            results = try modelContext.fetch(descriptor)
        } catch {
            print("⚠️ Failed to fetch books by ISBN: \(error)")
            return nil
        }

        // Filter in memory using normalizedForSearch()
        return results.first { book in
            book.isbn10?.normalizedForSearch() == normalizedQuery ||
            book.isbn13?.normalizedForSearch() == normalizedQuery
        }
    }
    
    /// Add a book to the search index
    func indexBook(_ book: Book) {
        // Index in semantic search
        Task {
            await semanticSearch.indexBook(book)
            // Save the updated index
            await semanticSearch.saveIndex()
        }

        // Persist metadata in background
        Task {
            await persistIndex()
        }
    }

    /// Remove a book from the search index
    func removeBook(id: UUID) {
        // Remove from semantic search
        Task {
            await semanticSearch.removeBook(id: id)
            // Save the updated index
            await semanticSearch.saveIndex()
        }

        // Persist metadata in background
        Task {
            await persistIndex()
        }
    }
    
    /// Rebuild the entire search index from the model context
    func rebuildIndex(from modelContext: ModelContext) async throws {
        print("🔄 Starting search index rebuild...")
        isIndexing = true
        indexProgress = 0.0

        defer {
            isIndexing = false
        }

        // Clear existing semantic index
        await semanticSearch.clearIndex()

        // Fetch all books
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        let books = try modelContext.fetch(descriptor)

        let total = books.count
        print("📚 Found \(total) books to index")

        guard total > 0 else {
            lastIndexedDate = Date()
            await semanticSearch.saveIndex()
            print("✅ No books to index")
            return
        }

        // Index books with progress updates
        for (index, book) in books.enumerated() {
            await semanticSearch.indexBook(book)

            // Update progress
            indexProgress = Double(index + 1) / Double(total)

            // Log progress every 10 books
            if (index + 1) % 10 == 0 {
                print("⏳ Indexed \(index + 1)/\(total) books (\(Int(indexProgress * 100))%)")
            }

            // Yield more frequently due to slower embedding generation
            if index % 5 == 0 {
                await Task.yield()
            }
        }

        lastIndexedDate = Date()
        indexProgress = 1.0
        print("✅ Search index rebuild completed: \(total) books indexed")

        // Save the index to disk for fast startup next time
        await semanticSearch.saveIndex()
        await persistIndex()
    }
    
    /// Check if index needs rebuilding (e.g., if book count doesn't match)
    func needsReindexing(modelContext: ModelContext) async throws -> Bool {
        let descriptor = FetchDescriptor<Book>()
        let bookCount = try modelContext.fetchCount(descriptor)

        // If no books in library, no need to rebuild
        if bookCount == 0 {
            return false
        }

        // Check if we have a persisted index
        if let lastSaved = await semanticSearch.persistenceManager.lastSavedDate() {
            print("📚 Found saved index from \(lastSaved)")

            // TODO: Implement proper change detection
            // For now, rebuild if it's been more than 24 hours since last index
            let hoursSinceIndex = Date().timeIntervalSince(lastSaved) / 3600

            if hoursSinceIndex > 24 {
                print("📚 Index is stale (\(Int(hoursSinceIndex))h old), rebuilding...")
                return true
            } else {
                print("✅ Index is recent (\(Int(hoursSinceIndex))h old), skipping rebuild")
                return false
            }
        }

        // No saved index found, need to rebuild
        print("📚 No saved index found, library has \(bookCount) books")
        return true
    }

    /// Get current index statistics
    var indexStats: IndexStats {
        IndexStats(
            bookCount: 0, // Semantic search doesn't expose count
            lastIndexedDate: lastIndexedDate
        )
    }
    
    // MARK: - Persistence

    private func persistIndex() async {
        // Persist metadata only (embeddings are rebuilt on startup)
        let metadata = SearchIndexMetadata(
            bookIds: [], // Not tracking individual book IDs for semantic search
            lastUpdated: Date(),
            version: 2 // Version 2 for semantic search
        )

        await persistenceManager.save(metadata: metadata)
    }

    private func loadPersistedIndex() async {
        guard let metadata = await persistenceManager.load() else {
            return
        }

        // Only load metadata, embeddings will be rebuilt when needed
        lastIndexedDate = metadata.lastUpdated
        // Note: Semantic search embeddings are rebuilt on startup for simplicity
        // In a production app, you might want to serialize the entire index
    }

    /// Clear persisted index data
    func clearPersistedData() async {
        await persistenceManager.clear()
        await semanticSearch.persistenceManager.clearIndex()
        await semanticSearch.clearIndex()
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

nonisolated struct SearchIndexMetadata: Codable {
    let bookIds: [UUID]
    let lastUpdated: Date
    let version: Int
}

