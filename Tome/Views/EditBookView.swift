import SwiftUI
import SwiftData

/// Edit book form with all editable fields
struct EditBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var book: Book

    @State private var title: String
    @State private var authors: String
    @State private var isbn10: String
    @State private var isbn13: String
    @State private var publisher: String
    @State private var year: String
    @State private var pageCount: String
    @State private var language: String
    @State private var description: String

    init(book: Book) {
        self.book = book
        _title = State(initialValue: book.title)
        _authors = State(initialValue: book.authors.joined(separator: ", "))
        _isbn10 = State(initialValue: book.isbn10 ?? "")
        _isbn13 = State(initialValue: book.isbn13 ?? "")
        _publisher = State(initialValue: book.publishers.first ?? "")
        _year = State(initialValue: book.firstPublishYear?.description ?? "")
        _pageCount = State(initialValue: book.pageCount?.description ?? "")
        _language = State(initialValue: book.languages.first ?? "")
        _description = State(initialValue: book.bookDescription ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Cover image section
                Section {
                    HStack {
                        Spacer()

                        BookCoverView(
                            coverURL: book.coverURL,
                            coverImageData: book.coverImageData,
                            size: .medium
                        )
                        .onTapGesture {
                            // Handle cover image change
                        }

                        Spacer()
                    }
                }

                // Basic information
                Section("Basic Information") {
                    TextField("Title", text: $title)

                    TextField("Author(s)", text: $authors)

                    HStack {
                        TextField("ISBN-10", text: $isbn10)
                        TextField("ISBN-13", text: $isbn13)
                    }
                }

                // Publication details
                Section("Publication Details") {
                    TextField("Publisher", text: $publisher)

                    HStack {
                        TextField("Year", text: $year)
                        TextField("Pages", text: $pageCount)
                    }

                    TextField("Language", text: $language)
                }

                // Description
                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                } header: {
                    Text("Description")
                } footer: {
                    Text("A brief description of the book, often from the publisher or jacket copy.")
                        .font(.caption)
                }

                // Subjects
                Section {
                    ForEach(book.subjects, id: \.self) { subject in
                        Text(subject)
                    }
                } header: {
                    Text("Subjects")
                } footer: {
                    Text("Subjects are automatically imported from OpenLibrary and cannot be edited here.")
                        .font(.caption)
                }

                // Metadata info
                Section {
                    HStack {
                        Text("OpenLibrary Key")
                        Spacer()
                        Text(book.openLibraryKey ?? "Manual Entry")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Date Added")
                        Spacer()
                        Text(book.dateAdded.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Metadata")
                }
            }
            .navigationTitle("Edit Book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        // Update book properties
        book.title = title
        book.authors = authors.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        book.isbn10 = isbn10.isEmpty ? nil : isbn10
        book.isbn13 = isbn13.isEmpty ? nil : isbn13
        book.publishers = publisher.isEmpty ? [] : [publisher]
        book.firstPublishYear = Int(year)
        book.pageCount = Int(pageCount)
        book.languages = language.isEmpty ? [] : [language]
        book.bookDescription = description.isEmpty ? nil : description
        book.dateModified = Date()

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let book = Book(
        title: "The Great Gatsby",
        authors: ["F. Scott Fitzgerald"],
        isbn13: "9780743273565",
        coverID: 12897091,
        firstPublishYear: 1925,
        bookDescription: "The story of the mysteriously wealthy Jay Gatsby and his love for the beautiful Daisy Buchanan.",
        publishers: ["Scribner"],
        pageCount: 180,
        languages: ["eng"],
        subjects: ["Jazz age", "Love stories"],
        readingStatus: .reading
    )

    return EditBookView(book: book)
}
