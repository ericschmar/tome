import Foundation

// MARK: - Search API Models

/// Search API response wrapper
struct OpenLibrarySearchResponse: Codable {
    let numFound: Int
    let start: Int
    let docs: [BookDocument]
}

/// Individual book document in search results
struct BookDocument: Codable, Equatable, Identifiable {
    let key: String
    let title: String
    let authorName: [String]?
    let authorKey: [String]?
    let isbn: [String]?
    let coverI: Int?
    let firstPublishYear: Int?
    let language: [String]?
    let publisher: [String]?
    let numberOfPagesMedian: Int?
    let subject: [String]?
    let publishYear: [Int]?
    let editionCount: Int?
    let ia: [String]?
    let ebookAccess: String?
    let lendingEditionS: String?
    let lendingIdentifierS: String?
    let publicScanB: Bool?
    
    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, title
        case authorName = "author_name"
        case authorKey = "author_key"
        case isbn
        case coverI = "cover_i"
        case firstPublishYear = "first_publish_year"
        case language
        case publisher
        case numberOfPagesMedian = "number_of_pages_median"
        case subject
        case publishYear = "publish_year"
        case editionCount = "edition_count"
        case ia
        case ebookAccess = "ebook_access"
        case lendingEditionS = "lending_edition_s"
        case lendingIdentifierS = "lending_identifier_s"
        case publicScanB = "public_scan_b"
    }

    /// Extract ISBN-10 if available
    var isbn10: String? {
        isbn?.first { $0.count == 10 }
    }

    /// Extract ISBN-13 if available
    var isbn13: String? {
        isbn?.first { $0.count == 13 }
    }
    
    /// Get preferred ISBN-10 based on language preference
    /// Falls back to first available ISBN-10 if no language match
    func preferredISBN10(for languageCode: String) -> String? {
        guard let isbns = isbn else { return nil }
        
        // Check if we have language information
        if let languages = language, !languages.isEmpty {
            // OpenLibrary uses ISO 639-2/B three-letter codes
            let preferredLanguages = languageCodeVariants(for: languageCode)
            
            // If we have a single language and it matches, use the first ISBN-10
            if languages.count == 1, preferredLanguages.contains(languages[0]) {
                return isbns.first { $0.count == 10 }
            }
        }
        
        // Fall back to first ISBN-10
        return isbns.first { $0.count == 10 }
    }
    
    /// Get preferred ISBN-13 based on language preference
    /// Falls back to first available ISBN-13 if no language match
    func preferredISBN13(for languageCode: String) -> String? {
        guard let isbns = isbn else { return nil }
        
        // Check if we have language information
        if let languages = language, !languages.isEmpty {
            // OpenLibrary uses ISO 639-2/B three-letter codes
            let preferredLanguages = languageCodeVariants(for: languageCode)
            
            // If we have a single language and it matches, use the first ISBN-13
            if languages.count == 1, preferredLanguages.contains(languages[0]) {
                return isbns.first { $0.count == 13 }
            }
        }
        
        // Fall back to first ISBN-13
        return isbns.first { $0.count == 13 }
    }
    
    /// Get language code variants (e.g., "en" -> ["en", "eng"])
    private func languageCodeVariants(for code: String) -> [String] {
        // Map two-letter codes to three-letter codes used by OpenLibrary
        let mapping: [String: String] = [
            "en": "eng",
            "es": "spa",
            "fr": "fre",
            "de": "ger",
            "it": "ita",
            "pt": "por",
            "zh": "chi",
            "ja": "jpn",
            "ko": "kor",
            "ru": "rus",
            "ar": "ara"
        ]
        
        var variants = [code]
        if let threeLetterCode = mapping[code] {
            variants.append(threeLetterCode)
        }
        return variants
    }

    /// Convert to Book model with language preference
    func toBook(preferredLanguage: BookLanguage? = nil) -> Book {
        let languageCode = preferredLanguage?.rawValue ?? "en"
        
        return Book(
            title: title,
            authors: authorName ?? [],
            isbn10: preferredISBN10(for: languageCode),
            isbn13: preferredISBN13(for: languageCode),
            coverID: coverI,
            firstPublishYear: firstPublishYear,
            publishers: publisher ?? [],
            pageCount: numberOfPagesMedian,
            languages: language ?? [],
            subjects: subject ?? [],
            openLibraryKey: key,
            readingStatus: .toRead
        )
    }
}

// MARK: - Works API Models

/// Detailed work information from Works API
struct WorkDetails: Codable {
    let key: String
    let title: String
    let description: DescriptionValue?
    let covers: [Int]?
    let subjectTimes: [String]?
    let subjects: [String]?
    let subjectPeople: [String]?
    let subjectPlaces: [String]?
    let authors: [AuthorReference]?
    let firstPublishDate: String?

    enum CodingKeys: String, CodingKey {
        case key, title, description, covers, authors
        case subjectTimes = "subject_times"
        case subjects
        case subjectPeople = "subject_people"
        case subjectPlaces = "subject_places"
        case firstPublishDate = "first_publish_date"
    }

    /// Extract primary cover ID
    var primaryCoverID: Int? {
        covers?.first
    }

    /// Get description as string
    var descriptionText: String? {
        switch description {
        case .string(let text):
            return text
        case .object(let obj):
            return obj.value
        case .none:
            return nil
        }
    }

    /// Extract author names (Note: Works API only returns author keys, not names)
    var authorNames: [String] {
        // Works API doesn't include author names directly
        // You would need to fetch them separately if needed
        []
    }
}

/// Author reference in Works API (just a key reference)
struct AuthorReference: Codable {
    let author: AuthorKey
    
    struct AuthorKey: Codable {
        let key: String
    }
}

/// Description can be either a string or an object
enum DescriptionValue: Codable {
    case string(String)
    case object(DescriptionObject)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let objectValue = try? container.decode(DescriptionObject.self) {
            self = .object(objectValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Description value is neither String nor DescriptionObject"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let text):
            try container.encode(text)
        case .object(let obj):
            try container.encode(obj)
        }
    }
}

/// Description object with type and value
struct DescriptionObject: Codable {
    let type: String
    let value: String
}

/// Author role information
struct AuthorRole: Codable {
    let type: AuthorType?
    let author: Author?

    enum CodingKeys: String, CodingKey {
        case type, author
    }
}

enum AuthorType: String, Codable {
    case primary = "/type/author_role"
}

struct Author: Codable {
    let key: String
    let name: String
    let personalName: String?
    let birthDate: String?
    let deathDate: String?

    enum CodingKeys: String, CodingKey {
        case key, name
        case personalName = "personal_name"
        case birthDate = "birth_date"
        case deathDate = "death_date"
    }
}

/// Publisher information
struct Publisher: Codable {
    let key: String
    let name: String
}

/// Language information
struct Language: Codable {
    let key: String
    let name: String?
}

// MARK: - Error Models

enum OpenLibraryError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case noResults
    case rateLimitExceeded
    case parsingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .noResults:
            return "No results found"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .parsingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}
