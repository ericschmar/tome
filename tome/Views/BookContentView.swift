import SwiftData
import SwiftUI

/// Unified book detail view that adapts for library books or search results
struct BookContentView: View {
    @Environment(\.modelContext) private var modelContext
    let source: BookContentSource
    var onAdd: (() -> Void)?
    var onBack: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAddTag = false
    @State private var showingAllPublishers = false
    @State private var showingCoverPicker = false
    
    @Query(sort: \Tag.name) private var allTags: [Tag]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header section with cover and title
                headerSection
                    .padding(.horizontal, 32)
                    .padding(.top, 24)

                Divider()
                    .padding(.horizontal, 32)

                // Metadata grid
                metadataSection
                    .padding(.horizontal, 32)

                // Description
                if let description = source.bookDescription, !description.isEmpty {
                    descriptionSection
                        .padding(.horizontal, 32)
                }

                // Library-only sections
                if source.isLibraryBook, let book = source.book {
                    Divider()
                        .padding(.horizontal, 32)

                    readingStatusSection
                        .padding(.horizontal, 32)

                    personalNotesSection
                        .padding(.horizontal, 32)

                    tagsSection
                        .padding(.horizontal, 32)
                }

                // Search-only: Add to Library button
                if !source.isLibraryBook {
                    actionSection
                        .padding(.horizontal, 32)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(displayTitle)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Delete Book", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteBook()
            }
        } message: {
            Text("Are you sure you want to delete this book from your library?")
        }
        .sheet(isPresented: $showingAddTag) {
            if let book = source.book {
                AddTagSheet(book: book)
            }
        }
        .sheet(isPresented: $showingCoverPicker) {
            if let book = source.book {
                CoverPickerSheet(book: book)
            }
        }
        .popover(isPresented: $showingAllPublishers) {
            allPublishersPopover
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 28) {
            BookCoverView(
                coverURL: source.coverURL,
                coverImageData: source.coverImageData,
                size: .medium
            )
            .contextMenu {
                if source.isLibraryBook {
                    Button {
                        showingCoverPicker = true
                    } label: {
                        Label("Choose Cover Photo", systemImage: "photo.on.rectangle.angled")
                    }

                    Divider()

                    if source.book?.coverImageData != nil {
                        Button(role: .destructive) {
                            if let book = source.book {
                                removeCoverImage(from: book)
                            }
                        } label: {
                            Label("Remove Cover Image", systemImage: "trash")
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(source.title)
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .textSelection(.enabled)

                Text(displayAuthors)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                if let year = source.firstPublishYear {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)

                        Text("Published \(String(year))")
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                }

                Spacer()
            }

            Spacer()

            // Delete button (top right) - only for library books
            if source.isLibraryBook {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help("Delete from library")
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("About This Book")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 4)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 14) {
                // Publishers
                if !source.publishers.isEmpty {
                    GridRow(alignment: .firstTextBaseline) {
                        Text("Publisher")
                            .gridColumnAlignment(.leading)
                            .frame(width: 90, alignment: .leading)
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)

                        publishersChips
                    }
                }

                // Languages
                if !source.languages.isEmpty {
                    GridRow(alignment: .firstTextBaseline) {
                        Text("Language")
                            .gridColumnAlignment(.leading)
                            .frame(width: 90, alignment: .leading)
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)

                        FlowingLayout(spacing: 6) {
                            ForEach(source.languages.sorted(), id: \.self) { lang in
                                LanguageBadge(languageCode: lang)
                            }
                        }
                    }
                }

                // Page count
                if let pages = source.pageCount {
                    GridRow(alignment: .firstTextBaseline) {
                        Text("Pages")
                            .gridColumnAlignment(.leading)
                            .frame(width: 90, alignment: .leading)
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)

                        Text("\(pages) pages")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }

                // ISBN
                if let isbn = source.isbn {
                    GridRow(alignment: .firstTextBaseline) {
                        Text("ISBN")
                            .gridColumnAlignment(.leading)
                            .frame(width: 90, alignment: .leading)
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)

                        Text(isbn)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }

                // Subjects
                if !source.subjects.isEmpty {
                    GridRow(alignment: .firstTextBaseline) {
                        Text("Subjects")
                            .gridColumnAlignment(.leading)
                            .frame(width: 90, alignment: .leading)
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)

                        Text(source.subjects.prefix(5).joined(separator: ", "))
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }

                // Date added (library only)
                if let dateAdded = source.dateAdded {
                    GridRow(alignment: .firstTextBaseline) {
                        Text("Added")
                            .gridColumnAlignment(.leading)
                            .frame(width: 90, alignment: .leading)
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)

                        Text(dateAdded.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var publishersChips: some View {
        let sortedPublishers = source.publishers.sorted()

        return HStack(spacing: 6) {
            if sortedPublishers.count <= 2 {
                ForEach(sortedPublishers, id: \.self) { publisher in
                    PublisherChip(publisher: publisher)
                        .textSelection(.enabled)
                }
            } else {
                PublisherChip(publisher: sortedPublishers[0])
                    .textSelection(.enabled)

                if sortedPublishers.count > 1 {
                    Button {
                        showingAllPublishers = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .semibold))

                            Text("\(sortedPublishers.count - 1) more")
                                .font(.system(size: 12, weight: .medium, design: .default))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundStyle(.secondary)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var allPublishersPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Publishers")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(source.publishers.sorted(), id: \.self) { publisher in
                    Text(publisher)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .frame(width: 240)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(source.bookDescription ?? "")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }

    private var readingStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading Status")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            if let book = source.book {
                ReadingStatusButtonGroup(
                    selectedStatus: .init(
                        get: { book.readingStatus },
                        set: {
                            book.readingStatus = $0
                            updateBook(book)
                        }
                    ))
            }
        }
    }

    private var personalNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Notes")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            if let book = source.book {
                TextEditor(
                    text: Binding(
                        get: { book.personalNotes },
                        set: {
                            book.personalNotes = $0
                            updateBook(book)
                        }
                    )
                )
                .frame(minHeight: 100)
                .font(.system(size: 13, weight: .regular, design: .default))
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tags")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Menu {
                    // Show existing tags that aren't already added to this book
                    if let book = source.book {
                        let availableTags = allTags.filter { tag in
                            !(book.tags?.contains(where: { $0.id == tag.id }) ?? false)
                        }
                        
                        if !availableTags.isEmpty {
                            ForEach(availableTags) { tag in
                                Button {
                                    addExistingTag(tag, to: book)
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: tag.colorHex) ?? .blue)
                                            .frame(width: 10, height: 10)
                                        Text(tag.name)
                                    }
                                }
                            }
                            
                            Divider()
                        }
                    }
                    
                    Button {
                        showingAddTag = true
                    } label: {
                        Label("Add New Tag", systemImage: "plus.circle")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            if let book = source.book {
                if book.tags?.isEmpty ?? true {
                    Text("No tags added")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(.tertiary)
                } else {
                    FlowingLayout(spacing: 6) {
                        ForEach(book.tags ?? []) { tag in
                            TagChip(tag: tag, isEditable: true) {
                                toggleTag(tag, in: book)
                            }
                        }
                    }
                }
            }
        }
    }

    private var actionSection: some View {
        Button(action: {
            onAdd?()
        }) {
            Text("Add to Library")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Computed Properties

    private var displayTitle: String {
        source.title.isEmpty ? "Untitled" : source.title
    }

    private var displayAuthors: String {
        source.authors.isEmpty ? "Unknown Author" : source.authors.joined(separator: ", ")
    }

    // MARK: - Actions

    private func updateBook(_ book: Book) {
        book.dateModified = Date()
        try? modelContext.save()
    }
    
    private func addExistingTag(_ tag: Tag, to book: Book) {
        // Initialize tags array if nil
        if book.tags == nil {
            book.tags = []
        }
        
        // Add tag if not already present
        if !(book.tags?.contains(where: { $0.id == tag.id }) ?? false) {
            book.tags?.append(tag)
            updateBook(book)
        }
    }

    private func toggleTag(_ tag: Tag, in book: Book) {
        // Initialize tags array if nil
        if book.tags == nil {
            book.tags = []
        }

        if book.tags?.contains(tag) == true {
            modelContext.removeTagFromBook(tag, book: book)
        } else {
            book.tags?.append(tag)
        }
        updateBook(book)
    }

    private func deleteBook() {
        if let book = source.book {
            // If onDelete closure is provided, use it (e.g., to update ViewModel)
            // Otherwise, delete directly from modelContext
            if onDelete != nil {
                onDelete?()
            } else {
                modelContext.delete(book)
                try? modelContext.save()
            }
            onBack?()
        }
    }

    private func removeCoverImage(from book: Book) {
        book.coverImageData = nil
        updateBook(book)
    }
}

// MARK: - Publisher Chip

struct PublisherChip: View {
    let publisher: String

    var body: some View {
        Text(publisher)
            .font(.system(size: 12, weight: .medium, design: .default))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(.primary)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Add Tag Sheet

struct AddTagSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var book: Book

    @State private var tagName = ""
    @State private var selectedColor: Color? = Color(hex: "#007AFF") ?? .blue
    @State private var createdTags: [Tag] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Tag creation section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create New Tag")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(spacing: 12) {
                        TextField("Tag name", text: $tagName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if !tagName.isEmpty {
                                    addTag()
                                }
                            }

                        PlatformColorPicker(
                            selection: Binding(
                                get: { selectedColor ?? .blue },
                                set: { selectedColor = $0 }
                            ),
                            supportsOpacity: false
                        )

                        Button {
                            addTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(tagName.isEmpty)
                        .opacity(tagName.isEmpty ? 0.5 : 1.0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Created tags list
                if !createdTags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Tags to Add")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            Spacer()

                            Text("\(createdTags.count)")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        ScrollView {
                            FlowingLayout(spacing: 8) {
                                ForEach(createdTags) { tag in
                                    TagChip(tag: tag, isEditable: true) {
                                        removeTag(tag)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Remove any created tags if cancelled
                        for tag in createdTags {
                            modelContext.delete(tag)
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        finishAdding()
                    }
                    .disabled(createdTags.isEmpty)
                }
            }
        }
    }

    private func addTag() {
        guard !tagName.isEmpty else { return }

        let colorHex = (selectedColor ?? .blue).toHex()
        let newTag = Tag(name: tagName, colorHex: colorHex)
        modelContext.insert(newTag)
        createdTags.append(newTag)

        // Reset for next tag
        tagName = ""
        selectedColor = randomColor()
    }

    private func removeTag(_ tag: Tag) {
        createdTags.removeAll { $0.id == tag.id }
        modelContext.delete(tag)
    }

    private func finishAdding() {
        // Initialize tags array if nil
        if book.tags == nil {
            book.tags = []
        }

        // Add all created tags to the book
        for tag in createdTags {
            if !(book.tags?.contains(where: { $0.id == tag.id }) ?? false) {
                book.tags?.append(tag)
            }
        }
        
        // Update the book's modification date
        book.dateModified = Date()
        
        // Save the context
        do {
            try modelContext.save()
            print("✅ Successfully saved \(createdTags.count) tags to book")
        } catch {
            print("❌ Failed to save tags: \(error.localizedDescription)")
        }
        
        dismiss()
    }

    private func randomColor() -> Color {
        let colors: [Color] = [
            Color(hex: "#007AFF") ?? .blue,
            Color(hex: "#5E5CE6") ?? .purple,
            Color(hex: "#AF52DE") ?? .purple,
            Color(hex: "#FF2D55") ?? .pink,
            Color(hex: "#FF9F0A") ?? .orange,
            Color(hex: "#FFD60A") ?? .yellow,
            Color(hex: "#30D158") ?? .green,
            Color(hex: "#64D2FF") ?? .cyan,
            Color(hex: "#BF5AF2") ?? .purple,
        ]
        return colors.randomElement() ?? .blue
    }
}

// MARK: - Cover Picker Sheet

struct CoverPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var book: Book

    @State private var availableCovers: [Int] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCoverID: Int?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading covers...")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Try Again") {
                            Task {
                                await loadCovers()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if availableCovers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No alternative covers available")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                            ], spacing: 16
                        ) {
                            ForEach(availableCovers, id: \.self) { coverID in
                                CoverOptionView(
                                    coverID: coverID,
                                    isSelected: selectedCoverID == coverID
                                        || (selectedCoverID == nil && book.coverID == coverID)
                                ) {
                                    selectedCoverID = coverID
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Choose Cover")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        selectCover()
                    }
                    .disabled(selectedCoverID == nil)
                }
            }
            .task {
                await loadCovers()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private func loadCovers() async {
        isLoading = true
        errorMessage = nil

        guard let openLibraryKey = book.openLibraryKey else {
            errorMessage = "This book doesn't have an Open Library reference"
            isLoading = false
            return
        }

        do {
            let workDetails = try await OpenLibraryService.shared.fetchBookDetails(
                openLibraryKey: openLibraryKey)

            await MainActor.run {
                if let covers = workDetails.covers, !covers.isEmpty {
                    availableCovers = covers
                    // Pre-select current cover if it exists
                    if let currentCover = book.coverID, covers.contains(currentCover) {
                        selectedCoverID = currentCover
                    } else {
                        selectedCoverID = covers.first
                    }
                } else {
                    availableCovers = []
                }
                isLoading = false
            }
        } catch {
            print("\(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to load covers: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func selectCover() {
        guard let coverID = selectedCoverID else { return }

        book.coverID = coverID
        book.coverImageData = nil  // Clear cached data to force reload
        book.dateModified = Date()

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Cover Option View

struct CoverOptionView: View {
    let coverID: Int
    let isSelected: Bool
    let onTap: () -> Void

    @State private var image: PlatformImage?
    @State private var isLoading = false
    @State private var loadError: Error?

    var coverURL: URL? {
        URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack {
                    if let image = image {
                        Image(platformImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 225)
                            .clipped()
                    } else if isLoading {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 225)
                            .overlay {
                                ProgressView()
                                    .controlSize(.small)
                            }
                    } else if let error = loadError {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 225)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.secondary)
                                    Text("Failed to load")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text(error.localizedDescription)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.tertiary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                }
                            }
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 225)
                            .overlay {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.clear,
                            lineWidth: 3
                        )
                )

                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Selected")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.tint)
                    .padding(.top, 8)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = coverURL else { return }

        isLoading = true
        loadError = nil

        do {
            print("🖼️ CoverOptionView: Loading cover \(coverID)")
            let loadedImage = try await ImageCacheService.shared.fetchImage(url: url)
            await MainActor.run {
                self.image = loadedImage
                self.isLoading = false
                print("✅ CoverOptionView: Successfully loaded cover \(coverID)")
            }
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
                print(
                    "❌ CoverOptionView: Failed to load cover \(coverID) - \(error.localizedDescription)"
                )
            }
        }
    }
}

// MARK: - ModelContext Extensions

extension ModelContext {
    /// Removes a tag from a book and deletes the tag if it's not used by any other books
    func removeTagFromBook(_ tag: Tag, book: Book) {
        // Initialize tags array if nil
        if book.tags == nil {
            book.tags = []
        }

        book.tags?.removeAll { $0 == tag }

        // Save changes first to ensure the relationship is updated
        try? save()

        // Check if this tag is used by any books
        let descriptor = FetchDescriptor<Book>()
        if let allBooks = try? fetch(descriptor) {
            let isTagInUse = allBooks.contains { $0.tags?.contains(tag) ?? false }

            // If no books use this tag, delete it
            if !isTagInUse {
                delete(tag)
                try? save()
            }
        }
    }
}

// MARK: - Preview

#Preview("Library Book") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Book.self, configurations: config)
    let context = container.mainContext

    let book = Book(
        title: "The Great Gatsby",
        authors: ["F. Scott Fitzgerald"],
        isbn13: "9780743273565",
        coverID: 12_897_091,
        firstPublishYear: 1925,
        bookDescription:
            "The story of the mysteriously wealthy Jay Gatsby and his love for the beautiful Daisy Buchanan.",
        publishers: ["Scribner"],
        pageCount: 180,
        languages: ["eng"],
        subjects: ["Jazz age", "Love stories", "Rich people"],
        personalNotes: "A classic American novel that captures the essence of the Jazz Age.",
        readingStatus: .reading
    )

    context.insert(book)

    return NavigationSplitView {
        Text("Sidebar")
    } content: {
        Text("Content")
    } detail: {
        BookContentView(source: .library(book))
    }
    .modelContainer(container)
}

#Preview("Search Result - Multiple Publishers") {
    NavigationSplitView {
        Text("Sidebar")
    } content: {
        Text("Content")
    } detail: {
        BookContentView(
            source: .search(
                BookDocument(
                    key: "/works/OL4610827W",
                    title: "The Great Gatsby",
                    authorName: ["F. Scott Fitzgerald"],
                    authorKey: ["/authors/OL..."],
                    isbn: ["9780743273565"],
                    coverI: 12_897_091,
                    firstPublishYear: 1925,
                    language: ["eng", "fre", "spa"],
                    publisher: [
                        "Scribner", "Penguin Classics", "Modern Library", "Vintage Books",
                        "Wordsworth Editions",
                    ],
                    numberOfPagesMedian: 180,
                    subject: ["Jazz age", "Love stories"],
                    publishYear: [1925],
                    editionCount: 10,
                    ia: [],
                    ebookAccess: nil,
                    lendingEditionS: nil,
                    lendingIdentifierS: nil,
                    publicScanB: nil
                )),
            onAdd: { print("Add to library") },
            onBack: { print("Back") }
        )
    }
}
