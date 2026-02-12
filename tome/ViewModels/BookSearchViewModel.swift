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
    var currentOffset = 0
    private let limit = 20

    // MARK: - Search

    func searchBooks() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil
        currentOffset = 0

        do {
            let results = try await service.searchBooksDebounced(query: searchQuery)
            searchResults = results
            hasMoreResults = results.count == limit
        } catch {
            self.errorMessage = error.localizedDescription
            searchResults = []
        }

        isLoading = false
    }

    func loadMoreResults() async {
        guard hasMoreResults && !isLoading else { return }

        isLoading = true

        do {
            currentOffset += limit
            let newResults = try await service.searchBooks(
                query: searchQuery,
                limit: limit,
                offset: currentOffset
            )
            searchResults.append(contentsOf: newResults)
            hasMoreResults = newResults.count == limit
        } catch {
            self.errorMessage = error.localizedDescription
            currentOffset -= limit  // Reset offset on error
        }

        isLoading = false
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        errorMessage = nil
        currentOffset = 0
        hasMoreResults = false
    }

    // MARK: - ISBN Lookup

    func lookupByISBN(_ isbn: String) async -> BookDocument? {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.lookupByISBN(isbn)
            isLoading = false
            return result
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    // MARK: - Book Details

    func fetchBookDetails(openLibraryKey: String) async -> WorkDetails? {
        isLoading = true
        errorMessage = nil

        do {
            let details = try await service.fetchBookDetails(openLibraryKey: openLibraryKey)
            isLoading = false
            return details
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
