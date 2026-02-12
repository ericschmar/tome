import Foundation

/// Enum wrapper for different book content sources
enum BookContentSource: BookDisplayable {
    case library(Book)
    case search(BookDocument)

    // MARK: - BookDisplayable Conformance

    var title: String {
        switch self {
        case .library(let book): return book.title
        case .search(let document): return document.title
        }
    }

    var authors: [String] {
        switch self {
        case .library(let book): return book.authors
        case .search(let document): return document.authorName ?? []
        }
    }

    var isbn: String? {
        switch self {
        case .library(let book): return book.isbn13 ?? book.isbn10
        case .search(let document):
            let languageCode = AppSettings.shared.defaultBookLanguage.rawValue
            return document.preferredISBN13(for: languageCode)
                ?? document.preferredISBN10(for: languageCode)
        }
    }

    var publisher: String? {
        switch self {
        case .library(let book): return book.publisher
        case .search(let document): return document.publisher?.first
        }
    }

    var firstPublishYear: Int? {
        switch self {
        case .library(let book): return book.firstPublishYear
        case .search(let document): return document.firstPublishYear
        }
    }

    var pageCount: Int? {
        switch self {
        case .library(let book): return book.pageCount
        case .search(let document): return document.numberOfPagesMedian
        }
    }

    var language: String? {
        switch self {
        case .library(let book): return book.language
        case .search(let document): return document.language?.first
        }
    }

    var subjects: [String] {
        switch self {
        case .library(let book): return book.subjects
        case .search(let document): return document.subject ?? []
        }
    }

    var bookDescription: String? {
        switch self {
        case .library(let book): return book.bookDescription
        case .search: return nil  // BookDocument doesn't have description
        }
    }

    var publishers: [String] {
        switch self {
        case .library(let book):
            return book.publishers
        case .search(let document):
            return document.publisher ?? []
        }
    }

    var languages: [String] {
        switch self {
        case .library(let book):
            return book.languages
        case .search(let document):
            return document.language ?? []
        }
    }

    // MARK: - Computed Properties

    var isLibraryBook: Bool {
        if case .library = self { return true }
        return false
    }

    var coverURL: URL? {
        switch self {
        case .library(let book):
            return book.coverURL
        case .search(let document):
            let languageCode = AppSettings.shared.defaultBookLanguage.rawValue
            let preferredISBN =
                document.preferredISBN10(for: languageCode)
                ?? document.preferredISBN13(for: languageCode)
            // Try preferred ISBN first (based on language preference), fall back to cover ID
            if let isbn = preferredISBN {
                return URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg")
            } else if let coverID = document.coverI {
                return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")
            }
            return nil
        }
    }

    /// For library books: returns the Book instance
    var book: Book? {
        if case .library(let book) = self { return book }
        return nil
    }

    /// For library books: returns the cover image data
    var coverImageData: Data? {
        if case .library(let book) = self { return book.coverImageData }
        return nil
    }

    /// For library books: returns the date added
    var dateAdded: Date? {
        if case .library(let book) = self { return book.dateAdded }
        return nil
    }
}
