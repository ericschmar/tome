import SwiftUI
import SwiftData

/// View for bulk adding multiple books to the library
struct BulkAddBooksView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = BulkAddViewModel()
    @FocusState private var isSearchFocused: Bool
    
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search results
            VStack(spacing: 12) {
                // ISBN hint if detected
                if viewModel.isISBNQuery {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("ISBN detected - auto-searching")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.opacity)
                }
                
                // Search results horizontal scroll
                if viewModel.isSearching {
                    ProgressView(viewModel.isISBNQuery ? "Looking up ISBN..." : "Searching...")
                        .frame(height: 240)
                } else if !viewModel.searchResults.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 36) {
                            ForEach(viewModel.searchResults, id: \.key) { result in
                                SearchResultCard(
                                    result: result,
                                    isSelected: viewModel.isSelected(result)
                                ) {
                                    viewModel.toggleSelection(result)
                                    // Clear search and focus search field after selection
                                    viewModel.clearSearch()
                                    isSearchFocused = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 240)
                } else if viewModel.hasSearched {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("No books found for '\(viewModel.searchQuery)'")
                    }
                    .frame(height: 240)
                }
            }
            .padding(.bottom, 16)
            
            Divider()
            
            // Selected books table
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Books to Add")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !viewModel.selectedBooks.isEmpty {
                        Text("\(viewModel.selectedBooks.count) book(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                
                if viewModel.selectedBooks.isEmpty {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        ContentUnavailableView {
                            Label("No Books Selected", systemImage: "books.vertical")
                        } description: {
                            Text("Search for books above and tap the + button to add them here.")
                        }
                        
                        Spacer()
                    }
                    
                    Spacer()
                } else {
                    Table(viewModel.selectedBooks) {
                        TableColumn("#") { book in
                            if let index = viewModel.selectedBooks.firstIndex(where: { $0.key == book.key }) {
                                Text("\(index + 1)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .width(30)
                        
                        TableColumn("Cover") { book in
                            BookCoverView(
                                coverURL: URL(string: "https://covers.openlibrary.org/b/id/\(book.coverI ?? 0)-S.jpg"),
                                coverImageData: nil,
                                size: .tiny
                            )
                        }
                        .width(70)
                        
                        TableColumn("Title") { book in
                            Text(book.title)
                                .textSelection(.enabled)
                                .lineLimit(2)
                        }
                        .width(min: 150, ideal: 250)
                        
                        TableColumn("Author(s)") { book in
                            Text(book.authorName?.joined(separator: ", ") ?? "Unknown")
                                .textSelection(.enabled)
                                .lineLimit(1)
                        }
                        .width(min: 150, ideal: 200)
                        
                        TableColumn("Year") { book in
                            if let year = book.firstPublishYear {
                                Text(String(year))
                                    .textSelection(.enabled)
                            } else {
                                Text("—")
                                    .textSelection(.enabled)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .width(60)
                        
                        TableColumn("ISBN") { book in
                            Text(book.isbn13 ?? book.isbn10 ?? "—")
                                .textSelection(.enabled)
                                .monospaced()
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .width(min: 100, ideal: 120)
                        
                        TableColumn("") { book in
                            Button {
                                viewModel.removeBook(book)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .width(30)
                    }
                }
            }
            
            Spacer()
            
            Divider()
            
            // Bottom action bar
            HStack {
                Button("Clear All") {
                    viewModel.clearAll()
                }
                .disabled(viewModel.selectedBooks.isEmpty)
                
                Spacer()
                
                Button("Cancel") {
                    onComplete()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add \(viewModel.selectedBooks.count) Book(s)") {
                    addBooksToLibrary()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.selectedBooks.isEmpty || viewModel.isAdding)
            }
            .padding()
        }
        .navigationTitle("Bulk Add Books")
        .frame(minWidth: 800, minHeight: 600)
        .searchable(
            text: $viewModel.searchQuery,
            prompt: "Search by title, author, or ISBN"
        )
        .focused($isSearchFocused)
        .onSubmit(of: .search) {
            Task {
                await viewModel.performSearch()
            }
        }
        .onChange(of: viewModel.searchQuery) { oldValue, newValue in
            // Auto-search when ISBN format is detected (10 or 13 digits)
            if viewModel.isISBNQuery && (newValue.filter { $0.isNumber }.count == 10 || newValue.filter { $0.isNumber }.count == 13) {
                Task {
                    await viewModel.performSearch()
                }
            }
        }
        .onAppear {
            // Focus search field on appear
            isSearchFocused = true
        }
    }
    
    // MARK: - Actions
    
    /// Check if a string is an ISBN (only digits, 10 or 13 characters)
    private func isISBN(_ text: String) -> Bool {
        let digitsOnly = text.filter { $0.isNumber }
        return digitsOnly.count == 10 || digitsOnly.count == 13
    }
    
    private func addBooksToLibrary() {
        viewModel.isAdding = true
        
        // Use the preferred language from settings
        let preferredLanguage = AppSettings.shared.defaultBookLanguage
        
        // Convert search results to Book models and insert them
        for result in viewModel.selectedBooks {
            let newBook = result.toBook(preferredLanguage: preferredLanguage)
            modelContext.insert(newBook)
        }
        
        // Save context
        do {
            try modelContext.save()
            onComplete()
        } catch {
            print("Error saving books: \(error)")
            viewModel.isAdding = false
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let result: BookDocument
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and author above the cover
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let authors = result.authorName?.prefix(1).joined(separator: ", ") {
                    Text(authors)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 120, height: 36, alignment: .topLeading)
            
            ZStack(alignment: .topTrailing) {
                // Cover image (using medium size - 120x180)
                BookCoverView(
                    coverURL: URL(string: "https://covers.openlibrary.org/b/id/\(result.coverI ?? 0)-M.jpg"),
                    coverImageData: nil,
                    size: .medium
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
                
                // Add/Remove button
                Button {
                    onToggle()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isSelected ? .green : .blue)
                        .background(
                            Circle()
                                .fill(.white)
                                .frame(width: 20, height: 20)
                        )
                }
                .buttonStyle(.plain)
                .padding(6)
            }
        }
    }
}

// MARK: - View Model

@Observable
final class BulkAddViewModel {
    var searchQuery: String = ""
    var searchResults: [BookDocument] = []
    var selectedBooks: [BookDocument] = []
    var isSearching: Bool = false
    var hasSearched: Bool = false
    var isAdding: Bool = false
    
    private let searchService = OpenLibraryService.shared
    
    /// Check if the current query is an ISBN
    var isISBNQuery: Bool {
        let digitsOnly = searchQuery.filter { $0.isNumber }
        return digitsOnly.count == 10 || digitsOnly.count == 13
    }
    
    func performSearch() async {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        hasSearched = false
        
        do {
            if isISBNQuery {
                // ISBN lookup
                let isbn = searchQuery.filter { $0.isNumber }
                if let result = try await searchService.lookupByISBN(isbn) {
                    await MainActor.run {
                        self.searchResults = [result]
                        self.isSearching = false
                        self.hasSearched = true
                    }
                } else {
                    await MainActor.run {
                        self.searchResults = []
                        self.isSearching = false
                        self.hasSearched = true
                    }
                }
            } else {
                // Regular search
                let results = try await searchService.searchBooks(query: searchQuery)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                    self.hasSearched = true
                }
            }
        } catch {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
                self.hasSearched = true
            }
            print("Search error: \(error)")
        }
    }
    
    func toggleSelection(_ book: BookDocument) {
        if let index = selectedBooks.firstIndex(where: { $0.key == book.key }) {
            selectedBooks.remove(at: index)
        } else {
            selectedBooks.append(book)
        }
    }
    
    func isSelected(_ book: BookDocument) -> Bool {
        selectedBooks.contains(where: { $0.key == book.key })
    }
    
    func removeBook(_ book: BookDocument) {
        selectedBooks.removeAll(where: { $0.key == book.key })
    }
    
    func clearAll() {
        selectedBooks.removeAll()
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        hasSearched = false
    }
}

// MARK: - Preview

#Preview {
    BulkAddBooksView {
        print("Complete")
    }
    .frame(width: 900, height: 700)
}
