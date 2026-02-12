import SwiftUI
import SwiftData

/// Search interface for library books with fuzzy matching
struct LibrarySearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchQuery = ""
    @State private var searchResults: [Book] = []
    @State private var selectedBook: Book?
    @State private var isPerformingInitialIndex = false
    @State private var showingIndexProgress = false
    
    private let searchService = BookSearchService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content
                if isPerformingInitialIndex {
                    indexingView
                } else if searchQuery.isEmpty {
                    emptyStateView
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Search Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            Task {
                                await rebuildIndex()
                            }
                        } label: {
                            Label("Rebuild Index", systemImage: "arrow.triangle.2.circlepath")
                        }
                        
                        Divider()
                        
                        Text(searchService.indexStats.formattedLastIndexed)
                            .font(.caption)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedBook) { book in
                BookDetailSheet(book: book)
            }
            .task {
                await performInitialIndexIfNeeded()
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search by title, author, ISBN, or subject", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .onChange(of: searchQuery) { _, newValue in
                        performSearch(query: newValue)
                    }
                
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if !searchQuery.isEmpty && !searchResults.isEmpty {
                HStack {
                    Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
        .background(.regularMaterial)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("Search Your Library")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Find books by title, author, ISBN, or subject")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Results
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("No Books Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your search terms")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Indexing View
    
    private var indexingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: searchService.indexProgress) {
                Text("Indexing Library...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(Int(searchService.indexProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 300)
            
            Text("Building search index for faster searches")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results List
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { book in
                    LibrarySearchResultRow(book: book)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectBook(id: book.id)
                        }

                    if book.id != searchResults.last?.id {
                        Divider()
                            .padding(.leading, 80)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchResults = searchService.search(query: query, in: modelContext)
    }
    
    private func performInitialIndexIfNeeded() async {
        do {
            if try searchService.needsReindexing(modelContext: modelContext) {
                isPerformingInitialIndex = true
                try await searchService.rebuildIndex(from: modelContext)
                isPerformingInitialIndex = false
            }
        } catch {
            print("❌ Failed to check/rebuild index: \(error)")
            isPerformingInitialIndex = false
        }
    }
    
    private func rebuildIndex() async {
        showingIndexProgress = true
        
        do {
            try await searchService.rebuildIndex(from: modelContext)
        } catch {
            print("❌ Failed to rebuild index: \(error)")
        }
        
        showingIndexProgress = false
        
        // Re-run search if there's a query
        if !searchQuery.isEmpty {
            performSearch(query: searchQuery)
        }
    }
    
    private func selectBook(id: UUID) {
        // Fetch the Book from SwiftData
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            if let book = try modelContext.fetch(descriptor).first {
                selectedBook = book
            }
        } catch {
            print("❌ Failed to fetch book: \(error)")
        }
    }
}

// MARK: - Library Search Result Row

struct LibrarySearchResultRow: View {
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Cover image placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 50, height: 70)
                .overlay {
                    Image(systemName: "book.fill")
                        .foregroundStyle(.tertiary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                if !book.authors.isEmpty {
                    Text(book.authorsDisplay)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label("Library", systemImage: "books.vertical")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if let year = book.firstPublishYear {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text("\(year)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Book Detail Sheet

struct BookDetailSheet: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Cover and basic info
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.quaternary)
                            .frame(width: 150, height: 220)
                            .overlay {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.tertiary)
                            }
                        
                        Text(book.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        if !book.authors.isEmpty {
                            Text(book.authorsDisplay)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    
                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        if let isbn10 = book.isbn10 {
                            detailRow(label: "ISBN-10", value: isbn10)
                        }
                        
                        if let isbn13 = book.isbn13 {
                            detailRow(label: "ISBN-13", value: isbn13)
                        }
                        
                        if let year = book.firstPublishYear {
                            detailRow(label: "Published", value: "\(year)")
                        }
                        
                        if !book.subjects.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Subjects")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(book.subjects.prefix(10), id: \.self) { subject in
                                        Text(subject)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(.quaternary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        
                        if let description = book.bookDescription {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(description)
                                    .font(.body)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Book Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.body)
        }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    LibrarySearchView()
        .modelContainer(for: Book.self, inMemory: true)
}
