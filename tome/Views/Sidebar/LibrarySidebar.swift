import SwiftData
import SwiftUI

/// Sidebar navigation for the library app
struct LibrarySidebar: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query private var books: [Book]

    @Binding var selectedDestination: NavigationDestination

    var body: some View {
        VStack(spacing: 0) {
            List {
                // Library section
                Section("Library") {
                    sidebarRow(for: .allBooks, badge: allBooksCount)
                    sidebarRow(for: .currentlyReading, badge: readingCount)
                    sidebarRow(for: .toRead, badge: toReadCount)
                    sidebarRow(for: .read, badge: readCount)
                }

                // Add Book section
                Section("Add Book") {
                    sidebarRow(for: .addBookSearch, badge: nil)
                    sidebarRow(for: .addBookManual, badge: nil)
#if os(macOS)
                    sidebarRow(for: .addBookBulk, badge: nil)
#endif
                }

                // Tags section (only show if there are tags)
                if !tags.isEmpty {
                    Section("Tags") {
                        ForEach(tags, id: \.id) { tag in
                            sidebarRow(for: .tag(tag), badge: tagBookCount(for: tag))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteTag(tag)
                                    } label: {
                                        Label("Delete Tag", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            // User profile at the bottom
            Divider()

            UserProfileView()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 220)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func sidebarRow(for destination: NavigationDestination, badge: Int?) -> some View {
        let isSelected = selectedDestination == destination

        Button {
            selectedDestination = destination
        } label: {
            HStack(spacing: 8) {
                Image(systemName: destination.icon)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Text(destination.displayName)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                if let badge = badge, badge > 0 {
                    Text("\(badge)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.gray.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.gray.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .tag(destination)
    }

    // MARK: - Computed Properties

    private var allBooksCount: Int {
        books.count
    }

    private var readingCount: Int {
        books.filter { $0.readingStatus == .reading }.count
    }

    private var toReadCount: Int {
        books.filter { $0.readingStatus == .toRead }.count
    }

    private var readCount: Int {
        books.filter { $0.readingStatus == .read }.count
    }

    private func tagBookCount(for tag: Tag) -> Int {
        books.filter { $0.tags?.contains(tag) ?? false }.count
    }

    // MARK: - Actions

    private func deleteTag(_ tag: Tag) {
        // If the currently selected destination is this tag, switch to all books
        if case .tag(let selectedTag) = selectedDestination, selectedTag.id == tag.id {
            selectedDestination = .allBooks
        }

        // Delete the tag (SwiftData will automatically nullify relationships)
        modelContext.delete(tag)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Book.self, Tag.self, configurations: config)

    // Add sample data
    let context = container.mainContext

    let tag1 = Tag(name: "Fiction")
    let tag2 = Tag(name: "Science")

    let book1 = Book(
        title: "Book 1",
        authors: ["Author 1"],
        readingStatus: .reading
    )
    book1.tags = [tag1]

    let book2 = Book(
        title: "Book 2",
        authors: ["Author 2"],
        readingStatus: .toRead
    )
    book2.tags = [tag1, tag2]

    let book3 = Book(
        title: "Book 3",
        authors: ["Author 3"],
        readingStatus: .read
    )

    context.insert(tag1)
    context.insert(tag2)
    context.insert(book1)
    context.insert(book2)
    context.insert(book3)

    return LibrarySidebar(selectedDestination: .constant(.allBooks))
        .modelContainer(container)
}
