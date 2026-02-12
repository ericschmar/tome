import Foundation

/// OpenLibrary API endpoint definitions
enum OpenLibraryEndpoints {
    /// Base URL for OpenLibrary API
    static let baseURL = "https://openlibrary.org"
    static let coversBaseURL = "https://covers.openlibrary.org"

    /// Search endpoint - Search for books by query
    static func search(query: String, limit: Int = 20, offset: Int = 0) -> URL? {
        var components = URLComponents(string: "\(baseURL)/search.json")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "fields", value: searchFields)
        ]
        return components?.url
    }

    /// Search by ISBN
    static func searchByISBN(_ isbn: String) -> URL? {
        var components = URLComponents(string: "\(baseURL)/search.json")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "isbn:\(isbn)"),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "fields", value: searchFields)
        ]
        return components?.url
    }

    /// Get work details by key
    static func workDetails(key: String) -> URL? {
        URL(string: "\(baseURL)\(key).json")
    }

    /// Get author details by key
    static func authorDetails(key: String) -> URL? {
        URL(string: "\(baseURL)\(key).json")
    }

    /// Cover image URL
    static func coverImage(coverID: Int, size: CoverSize = .medium) -> URL? {
        URL(string: "\(coversBaseURL)/b/id/\(coverID)-\(size.rawValue).jpg")
    }

    /// Cover image URL from ISBN
    static func coverImageByISBN(isbn: String, size: CoverSize = .medium) -> URL? {
        URL(string: "\(coversBaseURL)/b/isbn/\(isbn)-\(size.rawValue).jpg")
    }

    /// Comma-separated list of fields to fetch in search
    private static var searchFields: String {
        [
            "key",
            "title",
            "author_name",
            "author_key",
            "isbn",
            "cover_i",
            "first_publish_year",
            "language",
            "publisher",
//            "number_of_pages_median",
            "subject",
            "publish_year",
//            "edition_count"
        ].joined(separator: ",")
    }
}

/// Cover image sizes
enum CoverSize: String {
    case small = "S"
    case medium = "M"
    case large = "L"
}
