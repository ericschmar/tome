import Foundation

/// Represents a searchable book entry with pre-processed search fields
struct SearchableBook: Codable, Identifiable {
    let id: UUID
    let title: String
    let normalizedTitle: String
    let authors: [String]
    let normalizedAuthors: [String]
    let isbn10: String?
    let isbn13: String?
    let subjects: [String]
    let normalizedSubjects: [String]
    let dateAdded: Date
    
    init(from book: Book) {
        self.id = book.id
        self.title = book.title
        self.normalizedTitle = book.title.normalizedForSearch()
        self.authors = book.authors
        self.normalizedAuthors = book.authors.map { $0.normalizedForSearch() }
        self.isbn10 = book.isbn10
        self.isbn13 = book.isbn13
        self.subjects = book.subjects
        self.normalizedSubjects = book.subjects.map { $0.normalizedForSearch() }
        self.dateAdded = book.dateAdded
    }
}

/// In-memory search index with fuzzy matching capabilities
@MainActor
final class BookSearchIndex {
    private var books: [UUID: SearchableBook] = [:]
    private var titleIndex: [String: Set<UUID>] = [:]
    private var authorIndex: [String: Set<UUID>] = [:]
    private var isbnIndex: [String: UUID] = [:]
    private var subjectIndex: [String: Set<UUID>] = [:]
    
    /// Add or update a book in the search index
    func indexBook(_ book: Book) {
        let searchableBook = SearchableBook(from: book)
        
        // Remove old index entries if updating
        if books[book.id] != nil {
            removeBook(book.id)
        }
        
        books[book.id] = searchableBook
        
        // Index title words
        let titleWords = searchableBook.normalizedTitle.components(separatedBy: .whitespaces)
        for word in titleWords where !word.isEmpty {
            titleIndex[word, default: []].insert(book.id)
        }
        
        // Index author words
        for author in searchableBook.normalizedAuthors {
            let authorWords = author.components(separatedBy: .whitespaces)
            for word in authorWords where !word.isEmpty {
                authorIndex[word, default: []].insert(book.id)
            }
        }
        
        // Index ISBNs
        if let isbn10 = searchableBook.isbn10 {
            isbnIndex[isbn10.normalizedForSearch()] = book.id
        }
        if let isbn13 = searchableBook.isbn13 {
            isbnIndex[isbn13.normalizedForSearch()] = book.id
        }
        
        // Index subjects
        for subject in searchableBook.normalizedSubjects {
            let subjectWords = subject.components(separatedBy: .whitespaces)
            for word in subjectWords where !word.isEmpty {
                subjectIndex[word, default: []].insert(book.id)
            }
        }
    }
    
    /// Remove a book from the search index
    func removeBook(_ bookId: UUID) {
        guard let searchableBook = books[bookId] else { return }
        
        // Remove from title index
        let titleWords = searchableBook.normalizedTitle.components(separatedBy: .whitespaces)
        for word in titleWords {
            titleIndex[word]?.remove(bookId)
            if titleIndex[word]?.isEmpty == true {
                titleIndex.removeValue(forKey: word)
            }
        }
        
        // Remove from author index
        for author in searchableBook.normalizedAuthors {
            let authorWords = author.components(separatedBy: .whitespaces)
            for word in authorWords {
                authorIndex[word]?.remove(bookId)
                if authorIndex[word]?.isEmpty == true {
                    authorIndex.removeValue(forKey: word)
                }
            }
        }
        
        // Remove from ISBN index
        if let isbn10 = searchableBook.isbn10 {
            isbnIndex.removeValue(forKey: isbn10.normalizedForSearch())
        }
        if let isbn13 = searchableBook.isbn13 {
            isbnIndex.removeValue(forKey: isbn13.normalizedForSearch())
        }
        
        // Remove from subject index
        for subject in searchableBook.normalizedSubjects {
            let subjectWords = subject.components(separatedBy: .whitespaces)
            for word in subjectWords {
                subjectIndex[word]?.remove(bookId)
                if subjectIndex[word]?.isEmpty == true {
                    subjectIndex.removeValue(forKey: word)
                }
            }
        }
        
        books.removeValue(forKey: bookId)
    }
    
    /// Clear the entire index
    func clearIndex() {
        books.removeAll()
        titleIndex.removeAll()
        authorIndex.removeAll()
        isbnIndex.removeAll()
        subjectIndex.removeAll()
    }
    
    /// Search for books matching the query with fuzzy matching
    func search(query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        
        let normalizedQuery = query.normalizedForSearch()
        
        // Check for ISBN search first (exact match)
        if let bookId = isbnIndex[normalizedQuery] {
            if let book = books[bookId] {
                return [SearchResult(book: book, score: 1000, matchType: .isbn)]
            }
        }
        
        var results: [UUID: SearchResult] = [:]
        let queryWords = normalizedQuery.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Search in titles
        for (word, bookIds) in titleIndex {
            for queryWord in queryWords {
                if let score = fuzzyMatch(queryWord: queryWord, indexWord: word) {
                    for bookId in bookIds {
                        if let book = books[bookId] {
                            let existingScore = results[bookId]?.score ?? 0
                            let newScore = existingScore + (score * 10) // Title matches weighted higher
                            results[bookId] = SearchResult(
                                book: book,
                                score: newScore,
                                matchType: .title
                            )
                        }
                    }
                }
            }
        }
        
        // Search in authors
        for (word, bookIds) in authorIndex {
            for queryWord in queryWords {
                if let score = fuzzyMatch(queryWord: queryWord, indexWord: word) {
                    for bookId in bookIds {
                        if let book = books[bookId] {
                            let existingScore = results[bookId]?.score ?? 0
                            let newScore = existingScore + (score * 8) // Author matches weighted high
                            let matchType: MatchType = results[bookId]?.matchType == .title ? .title : .author
                            results[bookId] = SearchResult(
                                book: book,
                                score: newScore,
                                matchType: matchType
                            )
                        }
                    }
                }
            }
        }
        
        // Search in subjects
        for (word, bookIds) in subjectIndex {
            for queryWord in queryWords {
                if let score = fuzzyMatch(queryWord: queryWord, indexWord: word) {
                    for bookId in bookIds {
                        if let book = books[bookId] {
                            let existingScore = results[bookId]?.score ?? 0
                            let newScore = existingScore + (score * 3) // Subject matches weighted lower
                            let matchType: MatchType = results[bookId]?.matchType ?? .subject
                            results[bookId] = SearchResult(
                                book: book,
                                score: newScore,
                                matchType: matchType
                            )
                        }
                    }
                }
            }
        }
        
        // Sort by score (highest first) and then by date added (newest first)
        return results.values.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.book.dateAdded > rhs.book.dateAdded
        }
    }
    
    /// Get all indexed book IDs
    var indexedBookIds: Set<UUID> {
        Set(books.keys)
    }
    
    /// Get count of indexed books
    var count: Int {
        books.count
    }
    
    // MARK: - Fuzzy Matching
    
    /// Fuzzy match between query word and index word
    /// Returns score if match is good enough, nil otherwise
    private func fuzzyMatch(queryWord: String, indexWord: String) -> Double? {
        // Exact match
        if queryWord == indexWord {
            return 100.0
        }
        
        // Prefix match
        if indexWord.hasPrefix(queryWord) {
            let ratio = Double(queryWord.count) / Double(indexWord.count)
            return 50.0 * ratio
        }
        
        // Contains match
        if indexWord.contains(queryWord) {
            let ratio = Double(queryWord.count) / Double(indexWord.count)
            return 30.0 * ratio
        }
        
        // Levenshtein distance for fuzzy matching
        let distance = levenshteinDistance(queryWord, indexWord)
        let maxLength = max(queryWord.count, indexWord.count)
        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        
        // Only return score if similarity is above threshold
        if similarity >= 0.7 {
            return similarity * 25.0
        }
        
        return nil
    }
    
    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            matrix[i][0] = i
        }
        
        for j in 0...n {
            matrix[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,      // deletion
                        matrix[i][j - 1] + 1,      // insertion
                        matrix[i - 1][j - 1] + 1   // substitution
                    )
                }
            }
        }
        
        return matrix[m][n]
    }
}

// MARK: - Search Result

struct SearchResult: Identifiable {
    let book: SearchableBook
    let score: Double
    let matchType: MatchType
    
    var id: UUID { book.id }
}

enum MatchType {
    case title
    case author
    case isbn
    case subject
    
    var displayName: String {
        switch self {
        case .title: return "Title"
        case .author: return "Author"
        case .isbn: return "ISBN"
        case .subject: return "Subject"
        }
    }
}

// MARK: - String Extension

extension String {
    /// Normalize string for search: lowercase, trim, remove diacritics
    func normalizedForSearch() -> String {
        self.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: .punctuationCharacters)
            .joined()
    }
}
