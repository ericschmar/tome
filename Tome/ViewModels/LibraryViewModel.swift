import Foundation
import Observation
import SwiftData
import Combine
internal import CoreData

/// View model for managing library state
@MainActor
@Observable
final class LibraryViewModel {
    let modelContext: ModelContext
    let searchService = BookSearchService.shared

    var books: [Book] = []
    var filteredBooks: [Book] = []
    var searchText = "" {
        didSet {
            applyFiltersAndSort()
        }
    }
    private var debounceTask: Task<Void, Never>?
    nonisolated(unsafe) private var storeChangeObserver: NSObjectProtocol?
    var selectedStatus: ReadingStatus? {
        didSet {
            applyFiltersAndSort()
        }
    }
    var selectedTag: Tag? {
        didSet {
            applyFiltersAndSort()
        }
    }
    var selectedDestination: NavigationDestination = .allBooks {
        didSet {
            applyFiltersAndSort()
        }
    }
    var sortOption: SortOption = .dateAdded {
        didSet {
            applyFiltersAndSort()
        }
    }
    var sortDirection: SortDirection = .descending {
        didSet {
            applyFiltersAndSort()
        }
    }
    var isGridView = true

    enum SortOption: String, CaseIterable {
        case title = "Title"
        case author = "Author"
        case dateAdded = "Date Added"
        case year = "Publication Year"

        var displayName: String { rawValue }
    }

    enum SortDirection {
        case ascending
        case descending
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadBooks()

        // Reload books when CloudKit imports data from another device
        storeChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadBooks()
        }

        // Check if search index needs building
        Task {
            await checkAndRebuildSearchIndexIfNeeded()
        }
    }

    deinit {
        if let observer = storeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Book Management

    func loadBooks() {
        let descriptor = FetchDescriptor<Book>(sortBy: [
            SortDescriptor(\.dateAdded, order: .reverse)
        ])

        do {
            books = try modelContext.fetch(descriptor)
            applyFiltersAndSort()
        } catch {
            print("Failed to fetch books: \(error)")
        }
    }

    func addBook(_ book: Book) {
        modelContext.insert(book)
        try? modelContext.save()

        // Add to search index
        searchService.indexBook(book)

        loadBooks()
    }

    func updateBook(_ book: Book) {
        book.dateModified = Date()
        try? modelContext.save()

        // Re-index the book
        searchService.indexBook(book)

        loadBooks()
    }

    func deleteBook(_ book: Book) {
        let bookId = book.id
        modelContext.delete(book)
        try? modelContext.save()

        // Remove from search index
        searchService.removeBook(id: bookId)

        loadBooks()
    }

    func toggleReadingStatus(_ book: Book) {
        switch book.readingStatus {
        case .toRead:
            book.readingStatus = .reading
        case .reading:
            book.readingStatus = .read
        case .read:
            book.readingStatus = .toRead
        }
        updateBook(book)
    }

    // MARK: - Filtering and Sorting

    func applyFiltersAndSort() {
        // Cancel previous search
        debounceTask?.cancel()

        // If no search text, apply filters immediately
        if searchText.isEmpty {
            filteredBooks = books
            applyDestinationFilterAndSort()
            return
        }

        // Debounce by 300ms for semantic search
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
        let results = await searchService.search(query: searchText, in: modelContext)

        await MainActor.run {
            self.filteredBooks = results
            self.applyDestinationFilterAndSort()
        }
    }

    private func applyDestinationFilterAndSort() {
        // Apply destination filter (for status and tag destinations)
        switch selectedDestination {
        case .currentlyReading:
            filteredBooks = filteredBooks.filter { $0.readingStatus == .reading }
        case .toRead:
            filteredBooks = filteredBooks.filter { $0.readingStatus == .toRead }
        case .read:
            filteredBooks = filteredBooks.filter { $0.readingStatus == .read }
        case .tag(let tag):
            filteredBooks = filteredBooks.filter { $0.tags?.contains(tag) ?? false }
        case .allBooks, .addBookSearch, .addBookManual, .addBookBulk, .settings:
            break
        }

        // Apply sorting
        switch sortOption {
        case .title:
            if sortDirection == .ascending {
                filteredBooks.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
            } else {
                filteredBooks.sort { $0.title.localizedCompare($1.title) == .orderedDescending }
            }
        case .author:
            if sortDirection == .ascending {
                filteredBooks.sort {
                    $0.authorsDisplay.localizedCompare($1.authorsDisplay) == .orderedAscending
                }
            } else {
                filteredBooks.sort {
                    $0.authorsDisplay.localizedCompare($1.authorsDisplay) == .orderedDescending
                }
            }
        case .dateAdded:
            if sortDirection == .ascending {
                filteredBooks.sort { $0.dateAdded < $1.dateAdded }
            } else {
                filteredBooks.sort { $0.dateAdded > $1.dateAdded }
            }
        case .year:
            if sortDirection == .ascending {
                filteredBooks.sort { ($0.firstPublishYear ?? 0) < ($1.firstPublishYear ?? 0) }
            } else {
                filteredBooks.sort { ($0.firstPublishYear ?? 0) > ($1.firstPublishYear ?? 0) }
            }
        }
    }

    func updateSearchText(_ text: String) {
        searchText = text
    }

    func setSelectedStatus(_ status: ReadingStatus?) {
        selectedStatus = status
    }

    func setSelectedTag(_ tag: Tag?) {
        selectedTag = tag
    }

    func setSelectedDestination(_ destination: NavigationDestination) {
        selectedDestination = destination
    }

    func setSortOption(_ option: SortOption) {
        sortOption = option
    }

    // MARK: - Destination-based Filtering

    func books(for destination: NavigationDestination) -> [Book] {
        switch destination {
        case .allBooks, .currentlyReading, .toRead, .read, .tag:
            // Filtering is already done in applyFiltersAndSort()
            return filteredBooks
        case .addBookSearch, .addBookManual, .addBookBulk, .settings:
            return []
        }
    }

    // MARK: - Search Index Maintenance

    private func checkAndRebuildSearchIndexIfNeeded() async {
        print("🔍 Checking if search index needs rebuilding...")
        do {
            if try await searchService.needsReindexing(modelContext: modelContext) {
                print("📚 Search index rebuild needed, starting...")
                try await searchService.rebuildIndex(from: modelContext)
                print("✅ Search index rebuild completed")
            } else {
                print("✅ Search index is up to date")
            }
        } catch {
            print("❌ Failed to check/rebuild search index: \(error)")
        }
    }

    // MARK: - Statistics

    var totalBooks: Int {
        books.count
    }

    var readingCount: Int {
        books.filter { $0.readingStatus == .reading }.count
    }

    var toReadCount: Int {
        books.filter { $0.readingStatus == .toRead }.count
    }

    var readCount: Int {
        books.filter { $0.readingStatus == .read }.count
    }

    var allTags: [Tag] {
        let allTags = books.compactMap { $0.tags }.flatMap { $0 }
        return Array(Set(allTags)).sorted { $0.name < $1.name }
    }
}
