import SwiftUI

/// Reusable book display card for library views
struct BookCard: View {
    let book: Book
    var size: CardSize = .medium
    var onTap: (() -> Void)?

    enum CardSize {
        case small, medium, large

        var coverSize: BookCoverView.CoverSize {
            switch self {
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            }
        }
    }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover image
                BookCoverView(
                    coverURL: book.coverURL,
                    coverImageData: book.coverImageData,
                    size: size.coverSize
                )

                // Title and info
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)

                    Text(book.authorsDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if size != .small {
                        HStack {
                            Image(systemName: book.readingStatus.icon)
                                .font(.caption2)
                            Text(book.readingStatus.displayName)
                                .font(.caption2)
                        }
                        .foregroundStyle(statusColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch book.readingStatus {
        case .toRead: return .orange
        case .reading: return .blue
        case .read: return .green
        }
    }
}

#Preview {
    let sampleBook = Book(
        title: "The Great Gatsby",
        authors: ["F. Scott Fitzgerald"],
        firstPublishYear: 1925,
        readingStatus: .reading
    )

    return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
        BookCard(book: sampleBook, size: .small)
        BookCard(book: sampleBook, size: .medium)
        BookCard(book: sampleBook, size: .large)
    }
    .padding()
}
