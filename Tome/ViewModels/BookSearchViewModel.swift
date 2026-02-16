import Foundation
import Observation

/// View model for handling OpenLibrary book search
@MainActor
@Observable
final class BookSearchViewModel {
    private let service = OpenLibraryService.shared

    var searchResults: [BookDocument] = []
    var searchQuery = ""
    var isLoading = false
    var errorMessage: String?
    var hasMoreResults = false
    var hasPerformedSearch = false
    var currentOffset = 0
    private let limit = 20

    private var searchTask: Task<Void, Never>?

    // MARK: - Search

    func searchBooks() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            hasPerformedSearch = false
            return
        }

        isLoading = true
        errorMessage = nil
        currentOffset = 0

        searchTask = Task {
            do {
                let results = try await withTimeout(15.0) {
                    try await self.service.searchBooksDebounced(query: self.searchQuery)
                }
                guard !Task.isCancelled else { return }
                searchResults = results
                hasMoreResults = results.count == limit
                hasPerformedSearch = true
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
                searchResults = []
                hasPerformedSearch = true
            }
            isLoading = false
        }

        await searchTask?.value
    }

    func loadMoreResults() async {
        guard hasMoreResults && !isLoading else { return }

        isLoading = true

        searchTask = Task {
            do {
                currentOffset += limit
                let newResults = try await withTimeout(15.0) {
                    try await self.service.searchBooks(
                        query: self.searchQuery,
                        limit: self.limit,
                        offset: self.currentOffset
                    )
                }
                guard !Task.isCancelled else { return }
                searchResults.append(contentsOf: newResults)
                hasMoreResults = newResults.count == limit
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
                currentOffset -= limit  // Reset offset on error
            }
            isLoading = false
        }

        await searchTask?.value
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        errorMessage = nil
        currentOffset = 0
        hasMoreResults = false
        hasPerformedSearch = false
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        isLoading = false
    }

    // MARK: - ISBN Lookup

    func lookupByISBN(_ isbn: String) async -> BookDocument? {
        isLoading = true
        errorMessage = nil
        hasPerformedSearch = true

        let task = Task<BookDocument?, Never> {
            do {
                let result = try await withTimeout(15.0) {
                    try await self.service.lookupByISBN(isbn)
                }
                guard !Task.isCancelled else {
                    isLoading = false
                    return nil
                }
                isLoading = false
                return result
            } catch {
                guard !Task.isCancelled else { return nil }
                self.errorMessage = error.localizedDescription
                isLoading = false
                return nil
            }
        }

        return await task.value
    }

    // MARK: - Book Details

    func fetchBookDetails(openLibraryKey: String) async -> WorkDetails? {
        isLoading = true
        errorMessage = nil

        let task = Task<WorkDetails?, Never> {
            do {
                let details = try await withTimeout(15.0) {
                    try await self.service.fetchBookDetails(openLibraryKey: openLibraryKey)
                }
                guard !Task.isCancelled else {
                    isLoading = false
                    return nil
                }
                isLoading = false
                return details
            } catch {
                guard !Task.isCancelled else { return nil }
                self.errorMessage = error.localizedDescription
                isLoading = false
                return nil
            }
        }

        return await task.value
    }

    // MARK: - Timeout Helper

    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }

            // Add the timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw OpenLibraryError.timeout
            }

            // Return the first one to complete
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
