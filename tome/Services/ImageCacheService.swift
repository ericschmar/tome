import Foundation
import AppKit
import Observation

/// Image caching service with memory and disk storage
@MainActor
@Observable
final class ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let diskCache: URL
    private let session: URLSession

    private init() {
        // Setup memory cache
        memoryCache.countLimit = 100  // Max 100 images
        memoryCache.totalCostLimit = 50 * 1024 * 1024  // 50 MB

        // Setup disk cache
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCache = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: diskCache, withIntermediateDirectories: true)

        // Setup URL session
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: "image_cache"
        )
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public Methods

    /// Fetch image from cache or network
    func fetchImage(url: URL) async throws -> NSImage {
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: url.absoluteString as NSString) {
            print("✅ ImageCache: Found in memory cache - \(url.lastPathComponent)")
            return cachedImage
        }

        // Check disk cache
        let diskPath = diskCachePath(for: url)
        if FileManager.default.fileExists(atPath: diskPath.path) {
            if let data = try? Data(contentsOf: diskPath),
               let image = NSImage(data: data) {
                print("✅ ImageCache: Found in disk cache - \(url.lastPathComponent)")
                memoryCache.setObject(image, forKey: url.absoluteString as NSString)
                return image
            } else {
                print("⚠️ ImageCache: Disk cache file exists but couldn't load image - \(url.lastPathComponent)")
                // Remove corrupted cache file
                try? FileManager.default.removeItem(at: diskPath)
            }
        }

        // Download from network
        print("📥 ImageCache: Downloading from network - \(url.lastPathComponent)")
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ ImageCache: Invalid response type - \(url.lastPathComponent)")
            throw OpenLibraryError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ ImageCache: HTTP error \(httpResponse.statusCode) - \(url.lastPathComponent)")
            throw OpenLibraryError.invalidResponse
        }

        guard let image = NSImage(data: data) else {
            print("❌ ImageCache: Failed to create image from data (\(data.count) bytes) - \(url.lastPathComponent)")
            throw OpenLibraryError.parsingError(NSError(domain: "ImageCache", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode image data"
            ]))
        }

        print("✅ ImageCache: Successfully downloaded and created image - \(url.lastPathComponent)")
        // Cache the image
        cacheImage(image, for: url, originalData: data)

        return image
    }

    /// Fetch image data (for SwiftData storage)
    func fetchImageData(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenLibraryError.invalidResponse
        }

        return data
    }

    /// Cache an image for the given URL
    func cacheImage(_ image: NSImage, for url: URL, originalData: Data? = nil) {
        // Memory cache
        memoryCache.setObject(image, forKey: url.absoluteString as NSString)

        // Disk cache - prefer original data format
        let diskPath = diskCachePath(for: url)
        if let originalData = originalData {
            // Save in original format (JPEG/PNG/etc)
            try? originalData.write(to: diskPath)
            print("💾 ImageCache: Saved to disk in original format (\(originalData.count) bytes) - \(url.lastPathComponent)")
        } else if let tiffData = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            // Convert to PNG for better compatibility
            try? pngData.write(to: diskPath)
            print("💾 ImageCache: Saved to disk as PNG (\(pngData.count) bytes) - \(url.lastPathComponent)")
        }
    }

    /// Remove cached image for URL
    func removeCache(for url: URL) {
        memoryCache.removeObject(forKey: url.absoluteString as NSString)
        let diskPath = diskCachePath(for: url)
        try? FileManager.default.removeItem(at: diskPath)
    }

    /// Clear all cached images
    func clearAllCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCache)
        try? FileManager.default.createDirectory(at: diskCache, withIntermediateDirectories: true)
    }

    /// Get cache size in bytes
    func getCacheSize() -> Int64 {
        var size: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: diskCache, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }

    // MARK: - Private Helper Methods

    private func diskCachePath(for url: URL) -> URL {
        let filename = url.absoluteString.sha256()
        return diskCache.appendingPathComponent(filename)
    }
}

// MARK: - String SHA256 Extension

extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

import CommonCrypto
