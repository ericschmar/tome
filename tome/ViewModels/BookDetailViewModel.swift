import Foundation
import SwiftData
import AppKit
import Observation

/// View model for single book operations
@MainActor
@Observable
final class BookDetailViewModel {
    private let modelContext: ModelContext
    private let service = OpenLibraryService.shared
    private let imageCache = ImageCacheService.shared

    var book: Book
    var isLoading = false
    var errorMessage: String?
    var coverImage: NSImage?

    init(modelContext: ModelContext, book: Book) {
        self.modelContext = modelContext
        self.book = book
        loadCoverImage()
    }

    // MARK: - Book Operations

    func updateBook() {
        book.dateModified = Date()
        try? modelContext.save()
    }

    func updatePersonalNotes(_ notes: String) {
        book.personalNotes = notes
        updateBook()
    }

    func updateReadingStatus(_ status: ReadingStatus) {
        book.readingStatus = status
        updateBook()
    }

    func toggleTag(_ tag: Tag) {
        // Initialize tags array if nil
        if book.tags == nil {
            book.tags = []
        }
        
        if book.tags?.contains(tag) == true {
            modelContext.removeTagFromBook(tag, book: book)
        } else {
            book.tags?.append(tag)
        }
        updateBook()
    }

    func refreshFromOpenLibrary() async {
        guard let key = book.openLibraryKey else {
            errorMessage = "This book was not imported from OpenLibrary"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let details = try await service.fetchBookDetails(openLibraryKey: key)

            // Update book with new data
            book.bookDescription = details.descriptionText
            book.firstPublishYear = Int(details.firstPublishDate?.prefix(4) ?? "")
            if details.primaryCoverID != nil {
                book.coverID = details.primaryCoverID
            }
            book.subjects = details.subjects ?? []

            updateBook()
            loadCoverImage()
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Cover Image

    func loadCoverImage() {
        // Check if we have cached data
        if let imageData = book.coverImageData,
           let image = NSImage(data: imageData) {
            coverImage = image
            return
        }

        // Try to load from URL
        if let url = book.coverURL {
            Task {
                await fetchCoverImage(from: url)
            }
        }
    }

    private func fetchCoverImage(from url: URL) async {
        do {
            let image = try await imageCache.fetchImage(url: url)
            coverImage = image

            // Optionally save to book
            if let tiffData = image.tiffRepresentation {
                book.coverImageData = tiffData
                try? modelContext.save()
            }
        } catch {
            print("Failed to fetch cover image: \(error)")
        }
    }

    func downloadCoverImage() async {
        guard let url = book.coverURL else {
            errorMessage = "No cover image available"
            return
        }

        isLoading = true

        do {
            let data = try await imageCache.fetchImageData(url: url)
            book.coverImageData = data
            coverImage = NSImage(data: data)
            updateBook()
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteCoverImage() {
        book.coverImageData = nil
        coverImage = nil
        updateBook()
    }

    // MARK: - Computed Properties

    var displayTitle: String {
        book.title.isEmpty ? "Untitled" : book.title
    }

    var displayAuthors: String {
        book.authors.isEmpty ? "Unknown Author" : book.authorsDisplay
    }

    var displayYear: String {
        guard let year = book.firstPublishYear else { return "Unknown" }
        return String(year)
    }
}
