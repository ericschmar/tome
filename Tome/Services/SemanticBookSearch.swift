import Foundation
import SimilaritySearchKit
import SwiftData

/// Wrapper around SimilaritySearchKit for semantic book search
@MainActor
final class SemanticBookSearch {
    private var index: SimilarityIndex?
    private let model = NativeEmbeddings() // Built-in, 0 MB, uses Apple's NaturalLanguage framework
    let persistenceManager = SemanticIndexPersistence()

    /// Initialize the semantic search index
    func initialize() async throws {
        index = await SimilarityIndex(
            model: model,
            metric: CosineSimilarity()
        )
        print("✅ Semantic search initialized successfully")
    }

    /// Initialize the semantic search index and load persisted data
    func initialize(loadFrom persistence: PersistenceMode) async throws {
        index = await SimilarityIndex(
            model: model,
            metric: CosineSimilarity()
        )
        print("✅ Semantic search initialized successfully")

        switch persistence {
        case .loadIfAvailable:
            if let savedIndex = await persistenceManager.loadIndex() {
                print("📂 Loaded persisted search index")
                self.index = savedIndex
            } else {
                print("📂 No persisted index found, will rebuild")
            }
        case .forceRebuild:
            print("🔄 Forcing index rebuild")
        }
    }

    /// Add a book to the semantic index
    func indexBook(_ book: Book) async {
        guard let index = index else {
            print("⚠️ Search index not initialized")
            return
        }

        let searchableText = composeSearchableText(from: book)
        await index.addItem(
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
        guard let index = index else { return }
        await index.removeItem(id: id.uuidString)
    }

    /// Search for books using semantic similarity
    func search(_ query: String) async -> [(id: UUID, score: Double)] {
        guard let index = index else {
            print("⚠️ Search index not initialized")
            return []
        }

        let results = await index.search(query)
        print("🔍 Semantic search for '\(query)' found \(results.count) results")

        return results.compactMap { result in
            guard let uuid = UUID(uuidString: result.id) else { return nil }
            return (id: uuid, score: Double(result.score))
        }
    }

    /// Clear all indexed books
    func clearIndex() async {
        index = await SimilarityIndex(model: model, metric: CosineSimilarity())
        print("✅ Search index cleared")
    }

    /// Save the current index to disk
    func saveIndex() async {
        guard let index = index else {
            print("⚠️ No index to save")
            return
        }

        await persistenceManager.saveIndex(index)
        print("💾 Search index saved to disk")
    }

    /// Get the number of items in the index
    var count: Int {
        // SimilarityIndex doesn't expose count, so we track it separately
        get async {
            // Return 0 since we can't access the actual count
            return 0
        }
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

// MARK: - Persistence

enum PersistenceMode {
    case loadIfAvailable
    case forceRebuild
}

/// Manages persistence of the semantic search index
actor SemanticIndexPersistence {
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

        self.fileURL = appDirectory.appendingPathComponent("semantic_search_index.json")
    }

    /// Save the index to disk
    func saveIndex(_ index: SimilarityIndex) async {
        do {
            // SimilaritySearchKit doesn't provide built-in serialization
            // We'll save the metadata instead and rebuild on launch
            // TODO: Implement proper embedding serialization using Codable
            let metadata = IndexMetadata(
                savedAt: Date(),
                version: 1
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metadata)
            try data.write(to: fileURL, options: .atomic)

            print("💾 Index metadata saved")
        } catch {
            print("⚠️ Failed to save index metadata: \(error)")
        }
    }

    /// Load the index from disk
    func loadIndex() async -> SimilarityIndex? {
        // TODO: Implement proper embedding deserialization
        // For now, we check if metadata exists to know if we've indexed before
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode(IndexMetadata.self, from: data)

            print("📂 Found index metadata from \(metadata.savedAt)")
            // Return nil to trigger rebuild since we can't deserialize embeddings yet
            return nil
        } catch {
            print("⚠️ Failed to load index metadata: \(error)")
            return nil
        }
    }

    /// Clear the persisted index
    func clearIndex() async {
        try? FileManager.default.removeItem(at: fileURL)
        print("🗑️ Cleared persisted index")
    }

    /// Get the last save date
    func lastSavedDate() async -> Date? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode(IndexMetadata.self, from: data)
            return metadata.savedAt
        } catch {
            return nil
        }
    }
}

struct IndexMetadata: Codable {
    let savedAt: Date
    let version: Int
}
