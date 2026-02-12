import SwiftUI
import AppKit

/// Async image loading view for book covers with placeholder
struct BookCoverView: View {
    let coverURL: URL?
    let coverImageData: Data?
    let size: CoverSize

    enum CoverSize {
        case tiny, small, medium, large

        var dimension: CGFloat {
            switch self {
            case .tiny: return 40
            case .small: return 60
            case .medium: return 120
            case .large: return 200
            }
        }
    }

    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var imageCache = ImageCacheService.shared

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(contentMode: .fill)
            } else if let coverImageData = coverImageData,
                      let nsImage = NSImage(data: coverImageData) {
                Image(nsImage: nsImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                placeholderView
                    .overlay {
                        ProgressView()
                            .tint(.secondary)
                    }
            } else {
                placeholderView
            }
        }
        .frame(width: size.dimension, height: size.dimension * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 2)
        .task(id: coverURL) {
            await loadImage()
        }
    }

    private var placeholderView: some View {
        ZStack {
            Color(nsColor: .separatorColor)

            Image(systemName: "book.closed")
                .font(.system(size: size.dimension / 3))
                .foregroundStyle(.secondary)
        }
    }

    private func loadImage() async {
        guard let coverURL = coverURL else { return }

        isLoading = true

        do {
            let loadedImage = try await imageCache.fetchImage(url: coverURL)
            await MainActor.run {
                self.image = loadedImage
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BookCoverView(coverURL: URL(string: "https://covers.openlibrary.org/b/id/12897091-L.jpg"), coverImageData: nil, size: .small)
        BookCoverView(coverURL: URL(string: "https://covers.openlibrary.org/b/id/12897091-L.jpg"), coverImageData: nil, size: .medium)
        BookCoverView(coverURL: nil, coverImageData: nil, size: .large)
    }
    .padding()
}
