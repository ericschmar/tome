import Foundation
import Observation

/// Main API service for OpenLibrary integration
///
/// Note: For searching your local library, use `BookSearchService` instead.
/// This service is for searching the OpenLibrary API.
@MainActor
@Observable
final class OpenLibraryService {
    static let shared = OpenLibraryService()

    private let session: URLSession
    private let decoder: JSONDecoder

    /// Rate limiting state
    private var lastRequestTime: Date?
    private var requestCount = 0
    private let maxRequestsPerInterval = 80  // Conservative limit
    private let rateLimitWindow: TimeInterval = 300  // 5 minutes

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20 MB
            diskCapacity: 100 * 1024 * 1024    // 100 MB
        )
        self.session = URLSession(configuration: configuration)

        let jsonDecoder = JSONDecoder()
        // Don't use convertFromSnakeCase since BookDocument has explicit CodingKeys
        self.decoder = jsonDecoder
    }

    // MARK: - Search

    /// Search for books via OpenLibrary Search API
    func searchBooks(query: String, limit: Int = 20, offset: Int = 0) async throws -> [BookDocument] {
        guard let url = OpenLibraryEndpoints.search(query: query, limit: limit, offset: offset) else {
            throw OpenLibraryError.invalidURL
        }

        let response: OpenLibrarySearchResponse = try await performRequest(url: url)
        return response.docs
    }

    /// Search for books by ISBN
    func lookupByISBN(_ isbn: String) async throws -> BookDocument? {
        guard let url = OpenLibraryEndpoints.searchByISBN(isbn) else {
            throw OpenLibraryError.invalidURL
        }

        let response: OpenLibrarySearchResponse = try await performRequest(url: url)
        return response.docs.first
    }

    // MARK: - Details

    /// Fetch detailed book information by OpenLibrary key
    func fetchBookDetails(openLibraryKey: String) async throws -> WorkDetails {
        guard let url = OpenLibraryEndpoints.workDetails(key: openLibraryKey) else {
            throw OpenLibraryError.invalidURL
        }

        return try await performRequest(url: url)
    }

    /// Fetch complete book information and merge with existing book data
    func fetchCompleteBook(openLibraryKey: String) async throws -> Book {
        // First get the work details
        let details = try await fetchBookDetails(openLibraryKey: openLibraryKey)

        // Create book from details
        return Book(
            title: details.title,
            authors: details.authorNames,
            coverID: details.primaryCoverID,
            firstPublishYear: Int(details.firstPublishDate?.prefix(4) ?? ""),
            bookDescription: details.descriptionText,
            subjects: details.subjects ?? [],
            openLibraryKey: details.key,
            readingStatus: .toRead
        )
    }

    // MARK: - Cover Images

    /// Download and cache cover image
    func fetchCoverImage(coverID: Int, size: CoverSize = .large) async throws -> Data {
        guard let url = OpenLibraryEndpoints.coverImage(coverID: coverID, size: size) else {
            throw OpenLibraryError.invalidURL
        }

        // Check URLCache first
        if let cachedResponse = session.configuration.urlCache?.cachedResponse(for: URLRequest(url: url)),
           let image = cachedResponse.data as? Data {
            return image
        }

        // Download image
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenLibraryError.invalidResponse
        }

        return data
    }

    /// Download cover image by ISBN
    func fetchCoverImageByISBN(isbn: String, size: CoverSize = .large) async throws -> Data {
        guard let url = OpenLibraryEndpoints.coverImageByISBN(isbn: isbn, size: size) else {
            throw OpenLibraryError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenLibraryError.invalidResponse
        }

        return data
    }

    // MARK: - Private Helper Methods

    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        // Rate limiting
        try await checkRateLimit()

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenLibraryError.invalidResponse
        }

        // Handle rate limit
        if httpResponse.statusCode == 429 {
            throw OpenLibraryError.rateLimitExceeded
        }

        guard httpResponse.statusCode == 200 else {
            throw OpenLibraryError.invalidResponse
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            // Debug: Print the response JSON to see what we're actually getting
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ Failed to decode response for \(url)")
                print("📄 Raw JSON response:")
                print(jsonString)
                print("🔍 Decoding error: \(error)")
            }
            #endif
            throw OpenLibraryError.parsingError(error)
        }
    }

    private func checkRateLimit() async throws {
        let now = Date()

        if let lastTime = lastRequestTime {
            let timeSinceLastRequest = now.timeIntervalSince(lastTime)

            // Reset counter if we're outside the rate limit window
            if timeSinceLastRequest > rateLimitWindow {
                requestCount = 0
                lastRequestTime = now
                return
            }

            // Check if we've hit the rate limit
            if requestCount >= maxRequestsPerInterval {
                let waitTime = rateLimitWindow - timeSinceLastRequest
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                requestCount = 0
                lastRequestTime = Date()
            } else {
                // Add small delay between requests
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
                requestCount += 1
                lastRequestTime = now
            }
        } else {
            lastRequestTime = now
            requestCount = 1
        }
    }
}

// MARK: - Convenience Extensions

extension OpenLibraryService {
    /// Search books with debouncing for UI typing
    func searchBooksDebounced(query: String, delay: TimeInterval = 0.3) async throws -> [BookDocument] {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return try await searchBooks(query: query)
    }

    /// Batch fetch book details for multiple keys
    func fetchMultipleBookDetails(keys: [String]) async throws -> [WorkDetails] {
        try await withThrowingTaskGroup(of: (String, WorkDetails).self) { group in
            for key in keys {
                group.addTask {
                    let details = try await self.fetchBookDetails(openLibraryKey: key)
                    return (key, details)
                }
            }

            var results: [String: WorkDetails] = [:]
            for try await (key, details) in group {
                results[key] = details
            }

            return keys.compactMap { results[$0] }
        }
    }
}
