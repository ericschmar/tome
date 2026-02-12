import SwiftUI

/// OpenLibrary search result row component
struct SearchResultRow: View {
    let result: BookDocument
    var onTap: (() -> Void)?

    /// Get the preferred ISBN based on AppSettings language preference
    private var preferredISBN: String? {
        let languageCode = AppSettings.shared.defaultBookLanguage.rawValue
        return result.preferredISBN10(for: languageCode)
            ?? result.preferredISBN13(for: languageCode)
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                // Cover thumbnail
                AsyncImage(url: coverURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Book info
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.headline)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    if let authors = result.authorName, !authors.isEmpty {
                        Text(authors.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 6) {
                        if let year = result.firstPublishYear {
                            Text("Published \(String(year))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        if let isbn = preferredISBN {
                            Text("ISBN \(isbn)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var coverURL: URL? {
        // Try preferred ISBN first (based on language preference), fall back to cover ID
        if let isbn = preferredISBN {
            return URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-S.jpg")
        } else if let coverID = result.coverI {
            return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-S.jpg")
        }
        return nil
    }

    private var placeholderView: some View {
        Color(nsColor: .systemGray)
            .overlay {
                Image(systemName: "book.closed")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
    }
}

/// Small badge component for search results
struct Badge: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(nsColor: .systemGray))
        .foregroundStyle(.secondary)
        .clipShape(Capsule())
    }
}

#Preview {
    let sampleResult = BookDocument(
        key: "/works/OL4620079W",
        title: "The Great Gatsby",
        authorName: ["F. Scott Fitzgerald"],
        authorKey: ["/authors/OL114009A"],
        isbn: ["9780743273565"],
        coverI: 12_897_091,
        firstPublishYear: 1925,
        language: ["eng"],
        publisher: ["Scribner"],
        numberOfPagesMedian: 180,
        subject: ["Jazz age", "Love stories"],
        publishYear: [1925],
        editionCount: 120,
        ia: ["returnofking00tolk_1"],
        ebookAccess: nil,
        lendingEditionS: nil,
        lendingIdentifierS: nil,
        publicScanB: nil
    )

    VStack(spacing: 16) {
        SearchResultRow(result: sampleResult)
        Divider()
        SearchResultRow(result: sampleResult)
        Divider()
        SearchResultRow(result: sampleResult)
    }
    .padding()
}
