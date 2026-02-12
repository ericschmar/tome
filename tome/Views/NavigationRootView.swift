import SwiftData
import SwiftUI

/// Root navigation with NavigationSplitView for native macOS three-column layout
struct NavigationRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationState.self) private var navigationState
    @State private var viewModel: LibraryViewModel?

    var body: some View {
        Group {
            // Use different layouts based on whether the destination needs a detail pane
            if shouldShowDetailPane(navigationState.selectedDestination) {
                // Three-column layout for destinations with detail pane
                NavigationSplitView(columnVisibility: .constant(.all)) {
                    LibrarySidebar(
                        selectedDestination: Binding(
                            get: { navigationState.selectedDestination },
                            set: { newValue in
                                navigationState.selectedDestination = newValue
                                viewModel?.setSelectedDestination(newValue)
                                // Clear selected book/result when navigating to non-library destinations
                                switch newValue {
                                case .addBookSearch, .addBookManual, .addBookBulk, .settings:
                                    navigationState.selectedBook = nil
                                default:
                                    break
                                }
                            }
                        )
                    )
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                } content: {
                    contentForDestination(navigationState.selectedDestination)
                        .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
                } detail: {
                    detailForDestination(navigationState.selectedDestination)
                        .navigationSplitViewColumnWidth(min: 400, ideal: 600)
                }
            } else {
                // Two-column layout for destinations without detail pane
                NavigationSplitView {
                    LibrarySidebar(
                        selectedDestination: Binding(
                            get: { navigationState.selectedDestination },
                            set: { newValue in
                                navigationState.selectedDestination = newValue
                                viewModel?.setSelectedDestination(newValue)
                                // Clear selected book when navigating away from library
                                switch newValue {
                                case .addBookSearch, .addBookManual, .addBookBulk, .settings:
                                    navigationState.selectedBook = nil
                                default:
                                    break
                                }
                            }
                        )
                    )
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                } detail: {
                    // In two-column mode, the "detail" is actually the main content
                    contentForDestination(navigationState.selectedDestination)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = LibraryViewModel(modelContext: modelContext)
                // Sync the initial destination with navigation state
                viewModel?.setSelectedDestination(navigationState.selectedDestination)
            }
        }
    }

    // MARK: - Helper Methods

    /// Determines if a destination should show a detail pane (three-column layout)
    private func shouldShowDetailPane(_ destination: NavigationDestination) -> Bool {
        switch destination {
        case .allBooks, .currentlyReading, .toRead, .read, .tag:
            return true  // Library views need detail pane for book details
        case .addBookSearch:
            return true  // Search view needs detail pane for search results
        case .addBookManual, .addBookBulk:
            return false  // These are full-width forms
        case .settings:
            return false  // Settings is a single view
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private func contentForDestination(_ destination: NavigationDestination) -> some View {
        if let viewModel = viewModel {
            switch destination {
            case .allBooks, .currentlyReading, .toRead, .read, .tag:
                LibraryContentListView(
                    viewModel: viewModel,
                    destination: destination,
                    selectedBook: Binding(
                        get: { navigationState.selectedBook },
                        set: { navigationState.selectedBook = $0 }
                    )
                )
            case .addBookSearch:
                AddBookSearchWrapper {
                    onBookAdded($0)
                }
            case .addBookManual:
                AddBookManualWrapper {
                    onBookAdded($0)
                }
            case .addBookBulk:
                BulkAddBooksView {
                    // On complete, go back to library
                    navigationState.selectedDestination = .allBooks
                    viewModel.loadBooks()
                }
            case .settings:
                SettingsView()
            }
        } else {
            ProgressView()
        }
    }

    // MARK: - Detail Views

    /// Returns the detail pane content for three-column layouts
    @ViewBuilder
    private func detailForDestination(_ destination: NavigationDestination) -> some View {
        if let book = navigationState.selectedBook, isLibraryDestination(destination) {
            // Library book - show with edit/delete capabilities
            BookContentView(
                source: .library(book),
                onBack: {
                    withAnimation {
                        navigationState.selectedBook = nil
                    }
                },
                onDelete: {
                    viewModel?.deleteBook(book)
                }
            )
        } else if let result = navigationState.selectedSearchResult, destination == .addBookSearch {
            // Search result - show with "Add to Library" button
            BookContentView(
                source: .search(result),
                onAdd: {
                    addBookFromSearch(result)
                },
                onBack: {
                    withAnimation {
                        navigationState.selectedSearchResult = nil
                    }
                }
            )
        } else {
            // Show appropriate empty state
            detailViewForDestination(destination)
        }
    }

    // MARK: - Empty Detail View

    private var emptyDetailView: some View {
        ContentUnavailableView {
            Label("No Book Selected", systemImage: "book.closed")
        } description: {
            Text("Select a book from the list to view its details.")
        }
    }

    /// Returns true if the destination is a library section that shows book details
    private func isLibraryDestination(_ destination: NavigationDestination) -> Bool {
        switch destination {
        case .allBooks, .currentlyReading, .toRead, .read, .tag:
            return true
        case .addBookSearch, .addBookManual, .addBookBulk, .settings:
            return false
        }
    }

    /// Returns the appropriate detail view for each destination
    @ViewBuilder
    private func detailViewForDestination(_ destination: NavigationDestination) -> some View {
        switch destination {
        case .addBookSearch:
            ContentUnavailableView {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            } description: {
                Text(
                    "Search for a book by title, author, or ISBN, then select it to view details here."
                )
            }
        case .settings:
            ContentUnavailableView {
                Image(systemName: "gear")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            } description: {
                Text("Adjust your app settings using the options in the content area.")
            }
        default:
            emptyDetailView
        }
    }

    // MARK: - Actions

    private func onBookAdded(_ book: Book) {
        // Navigate back to library and select the new book
        navigationState.selectedDestination = .allBooks
        navigationState.selectedBook = book
        // Reload the view model to show the new book
        viewModel?.loadBooks()
    }

    /// Add book from search result to library
    private func addBookFromSearch(_ result: BookDocument) {
        // Use the preferred language from settings
        let preferredLanguage = AppSettings.shared.defaultBookLanguage
        let newBook = result.toBook(preferredLanguage: preferredLanguage)
        modelContext.insert(newBook)
        try? modelContext.save()
        // Navigate to library and select new book
        navigationState.selectedDestination = .allBooks
        navigationState.selectedBook = newBook
        navigationState.selectedSearchResult = nil
        // Reload view model to show new book
        viewModel?.loadBooks()
    }
}

/// Library content view for displaying filtered books
struct LibraryContentListView: View {
    @Bindable var viewModel: LibraryViewModel
    let destination: NavigationDestination
    @Binding var selectedBook: Book?
    @State private var showingFilters = false

    private var booksForDestination: [Book] {
        viewModel.books(for: destination)
    }

    var body: some View {
        Group {
            if booksForDestination.isEmpty {
                emptyStateView
            } else {
                if viewModel.isGridView {
                    gridView(books: booksForDestination)
                } else {
                    listView(books: booksForDestination)
                }
            }
        }
        .navigationTitle(destination.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingFilters.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }

            ToolbarItem(placement: .automatic) {
                HStack {
                    Button {
                        withAnimation {
                            viewModel.isGridView.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.2x2")
                    }
                }
            }
        }
        .searchable(
            text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.updateSearchText($0) }
            ), prompt: "Search library"
        )
        .popover(isPresented: $showingFilters) {
            FilterPopover(viewModel: viewModel)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Books", systemImage: "books.vertical")
        } description: {
            Text("No books found in this section.")
        }
    }

    private func gridView(books: [Book]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 16)
                ], spacing: 20
            ) {
                ForEach(books) { book in
                    BookCard(book: book) {
                        selectedBook = book
                    }
                }
            }
            .padding()
        }
    }

    private func listView(books: [Book]) -> some View {
        List {
            ForEach(books) { book in
                Button {
                    selectedBook = book
                } label: {
                    HStack(spacing: 12) {
                        BookCoverView(
                            coverURL: book.smallCoverURL,
                            coverImageData: book.coverImageData,
                            size: .small
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)
                                .lineLimit(2)

                            Text(book.authorsDisplay)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 6) {
                                Image(systemName: book.readingStatus.icon)
                                    .font(.caption2)
                                Text(book.readingStatus.displayName)
                                    .font(.caption2)
                            }
                            .foregroundStyle(book.readingStatus.color)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }
}

/// Filter popover as an alternative to sheet
struct FilterPopover: View {
    @Bindable var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filters & Sort")
                .font(.headline)

            Divider()

            Group {
                Picker("Sort By", selection: $viewModel.sortOption) {
                    ForEach(LibraryViewModel.SortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Direction")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $viewModel.sortDirection) {
                        Text("Ascending").tag(LibraryViewModel.SortDirection.ascending)
                        Text("Descending").tag(LibraryViewModel.SortDirection.descending)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                Picker("Reading Status", selection: $viewModel.selectedStatus) {
                    Text("All").tag(nil as ReadingStatus?)
                    ForEach(ReadingStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status as ReadingStatus?)
                    }
                }
                .pickerStyle(.menu)

                if !viewModel.allTags.isEmpty {
                    Picker("Tag", selection: $viewModel.selectedTag) {
                        Text("All").tag(nil as Tag?)
                        ForEach(viewModel.allTags, id: \.id) { tag in
                            Text(tag.name).tag(tag as Tag?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Statistics")
                    .font(.headline)

                HStack {
                    Text("Total Books")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.totalBooks)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Reading")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.readingCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("To Read")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.toReadCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Read")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.readCount)")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

#Preview {
    NavigationRootView()
}
