import Foundation
import SwiftData

/// Primary book model with OpenLibrary metadata and personal tracking
@Model
final class Book {
    var id: UUID = UUID()
    var title: String = ""
    var authors: [String] = []
    var isbn10: String?
    var isbn13: String?
    var coverID: Int?
    var coverImageData: Data?
    var firstPublishYear: Int?
    var bookDescription: String?
    var publishers: [String] = []
    var pageCount: Int?
    var languages: [String] = []
    var subjects: [String] = []
    var openLibraryKey: String?
    var personalNotes: String = ""
    var readingStatusRaw: String = "toRead"
    var dateAdded: Date = Date()
    var dateModified: Date = Date()
    var sortOrder: Int = 0

    @Relationship(deleteRule: .nullify)
    var tags: [Tag]?

    init(
        id: UUID = UUID(),
        title: String = "",
        authors: [String] = [],
        isbn10: String? = nil,
        isbn13: String? = nil,
        coverID: Int? = nil,
        coverImageData: Data? = nil,
        firstPublishYear: Int? = nil,
        bookDescription: String? = nil,
        publishers: [String] = [],
        pageCount: Int? = nil,
        languages: [String] = [],
        subjects: [String] = [],
        openLibraryKey: String? = nil,
        personalNotes: String = "",
        readingStatus: ReadingStatus = .toRead,
        dateAdded: Date = Date(),
        dateModified: Date = Date(),
        sortOrder: Int = 0,
        tags: [Tag]? = nil
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.isbn10 = isbn10
        self.isbn13 = isbn13
        self.coverID = coverID
        self.coverImageData = coverImageData
        self.firstPublishYear = firstPublishYear
        self.bookDescription = bookDescription
        self.publishers = publishers
        self.pageCount = pageCount
        self.languages = languages
        self.subjects = subjects
        self.openLibraryKey = openLibraryKey
        self.personalNotes = personalNotes
        self.readingStatusRaw = readingStatus.rawValue
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.sortOrder = sortOrder
        self.tags = tags
    }

    /// Computed property for reading status
    var readingStatus: ReadingStatus {
        get { ReadingStatus(rawValue: readingStatusRaw) ?? .toRead }
        set { readingStatusRaw = newValue.rawValue }
    }

    /// Computed property for cover URL
    var coverURL: URL? {
        guard let coverID = coverID else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")
    }

    /// Small cover URL for list views
    var smallCoverURL: URL? {
        guard let coverID = coverID else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-M.jpg")
    }

    /// Backward compatibility: single publisher value
    var publisher: String? {
        publishers.first
    }

    /// Backward compatibility: single language value
    var language: String? {
        languages.first
    }

    /// Display name for authors
    var authorsDisplay: String {
        authors.joined(separator: ", ")
    }

    /// Display name for subjects
    var subjectsDisplay: String {
        subjects.prefix(3).joined(separator: ", ")
    }
}
