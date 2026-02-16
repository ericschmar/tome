import Foundation
import Vision
import CoreImage
@preconcurrency import AVFoundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Vision framework wrapper service for book cover scanning
@MainActor
@Observable
final class BookCoverScanner {

    static let shared = BookCoverScanner()

    private init() {}

    // MARK: - Rectangle Detection

    /// Detect rectangles in image (for auto-cropping)
    func detectRectangles(in image: PlatformImage) async throws -> [DetectedRectangle] {
        guard let cgImage = image.toCGImage else {
            throw ScannerError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let rectangles = observations.compactMap { observation -> DetectedRectangle? in
                    // Filter for book-like aspect ratios (typically 0.6 to 0.75 for most books)
                    let boundingBox = observation.boundingBox

                    // Calculate aspect ratio
                    let width = boundingBox.width
                    let height = boundingBox.height
                    let aspectRatio = width / height

                    // Accept reasonable book aspect ratios (0.5 to 1.5)
                    guard aspectRatio >= 0.5 && aspectRatio <= 1.5 else {
                        return nil
                    }

                    // Filter by confidence
                    guard observation.confidence > 0.6 else {
                        return nil
                    }

                    return DetectedRectangle(
                        boundingBox: boundingBox,
                        confidence: observation.confidence
                    )
                }

                continuation.resume(returning: rectangles)
            }

            // Configure request for book detection
            request.minimumAspectRatio = 0.5
            request.maximumAspectRatio = 1.5
            request.minimumConfidence = 0.6
            request.maximumObservations = 10

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            // Vision framework types are safe to use across concurrency boundaries
            nonisolated(unsafe) let localHandler = handler
            nonisolated(unsafe) let localRequest = request

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try localHandler.perform([localRequest])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Image Cropping

    /// Crop image to detected rectangle
    func cropImage(_ image: PlatformImage, to rectangle: DetectedRectangle) async throws -> Data {
        guard let cgImage = image.toCGImage else {
            throw ScannerError.invalidImage
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let boundingBox = rectangle.boundingBox

        // Convert normalized coordinates (0-1) to pixel coordinates
        // Vision coordinates origin is at bottom-left, need to flip to top-left
        let rect = CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        // Crop the image
        guard let croppedCGImage = cgImage.cropping(to: rect) else {
            throw ScannerError.cropFailed
        }

        // Convert back to PlatformImage and then to JPEG data
        #if os(macOS)
        let croppedImage = NSImage(cgImage: croppedCGImage, size: .zero)
        guard let imageData = croppedImage.jpegData(compressionQuality: 0.85) else {
            throw ScannerError.encodingFailed
        }
        #else
        let croppedImage = UIImage(cgImage: croppedCGImage)
        guard let imageData = croppedImage.jpegData(compressionQuality: 0.85) else {
            throw ScannerError.encodingFailed
        }
        #endif

        return imageData
    }

    // MARK: - Barcode Detection

    /// Detect barcode/ISBN in image
    func detectBarcode(from image: PlatformImage) async throws -> String? {
        guard let cgImage = image.toCGImage else {
            throw ScannerError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Look for EAN-13 barcode (ISBN-13)
                for observation in observations {
                    if observation.symbology == .ean13,
                       let payload = observation.payloadStringValue {
                        // Validate ISBN-13 checksum
                        if self.isValidISBN13(payload) {
                            continuation.resume(returning: payload)
                            return
                        }
                    }
                }

                continuation.resume(returning: nil)
            }

            // Configure request
            request.symbologies = [.ean13]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            // Vision framework types are safe to use across concurrency boundaries
            nonisolated(unsafe) let localHandler = handler
            nonisolated(unsafe) let localRequest = request

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try localHandler.perform([localRequest])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - OCR Text Extraction

    /// Extract text via OCR
    func extractText(from image: PlatformImage) async throws -> OCRResult {
        guard let cgImage = image.toCGImage else {
            throw ScannerError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ScannerError.noTextFound)
                    return
                }

                // Extract text with highest confidence candidates
                var extractedTexts: [(text: String, confidence: Float)] = []

                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        extractedTexts.append((
                            text: topCandidate.string,
                            confidence: topCandidate.confidence
                        ))
                    }
                }

                // Sort by vertical position (top to bottom) to maintain reading order
                // Vision coordinates origin is bottom-left, so higher y = lower on screen
                // We need to sort by y position in descending order
                let sortedTexts = extractedTexts.sorted { $0.confidence > $1.confidence }

                // Combine all text
                let fullText = sortedTexts.map { $0.text }.joined(separator: "\n")

                // Calculate average confidence
                let avgConfidence = sortedTexts.isEmpty ? 0.0 :
                    sortedTexts.map { $0.confidence }.reduce(0, +) / Float(sortedTexts.count)

                let result = OCRResult(text: fullText, confidence: avgConfidence)
                continuation.resume(returning: result)
            }

            // Configure request for accurate text recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "en-GB"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            // Vision framework types are safe to use across concurrency boundaries
            nonisolated(unsafe) let localHandler = handler
            nonisolated(unsafe) let localRequest = request

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try localHandler.perform([localRequest])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Text Parsing

    /// Parse title and author from OCR text
    func parseBookInfo(from text: String) -> BookInfo? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        var title = ""
        var authors: [String] = []
        var isbn: String? = nil

        // Look for ISBN pattern in text
        for line in lines {
            if let detectedISBN = extractISBN(from: line) {
                isbn = detectedISBN
                break
            }
        }

        // Find title (usually the first prominent line)
        // Look for keywords that indicate author lines
        var authorLineIndex: Int?

        for (index, line) in lines.enumerated() {
            let lowercaseLine = line.lowercased()

            // Check for "by" or "author" keywords
            if lowercaseLine.contains(" by ") ||
               lowercaseLine.hasPrefix("by ") ||
               lowercaseLine.contains("author") {
                authorLineIndex = index
                break
            }
        }

        if let authorIndex = authorLineIndex, authorIndex > 0 {
            // Title is everything before the author line
            title = lines[0..<authorIndex].joined(separator: " ")

            // Author is the line after "by" or the whole line
            let authorLine = lines[authorIndex]
            if let byRange = authorLine.range(of: " by ", options: .caseInsensitive) {
                let authorText = String(authorLine[byRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                authors = parseAuthors(authorText)
            } else if authorLine.lowercased().hasPrefix("by ") {
                let authorText = String(authorLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                authors = parseAuthors(authorText)
            } else {
                authors = parseAuthors(authorLine)
            }
        } else if lines.count >= 2 {
            // No "by" found, assume first line is title, second is author
            title = lines[0]
            authors = parseAuthors(lines[1])
        } else if lines.count == 1 {
            // Only one line, assume it's the title
            title = lines[0]
        }

        // Clean up title
        title = cleanTitle(title)

        // Validate we have meaningful data
        guard !title.isEmpty else { return nil }

        // Calculate confidence based on what we found
        var confidence: Float = 0.5
        if !authors.isEmpty { confidence += 0.2 }
        if isbn != nil { confidence += 0.3 }

        return BookInfo(
            title: title,
            authors: authors,
            isbn: isbn,
            confidence: min(confidence, 1.0)
        )
    }

    // MARK: - Helper Methods

    private func parseAuthors(_ authorText: String) -> [String] {
        // Split by common separators - split multiple times
        var authors = [authorText]

        // Split by "and" (case insensitive)
        authors = authors.flatMap { $0.components(separatedBy: " and ").map { $0.trimmingCharacters(in: .whitespaces) } }
        authors = authors.flatMap { $0.components(separatedBy: " And ").map { $0.trimmingCharacters(in: .whitespaces) } }
        authors = authors.flatMap { $0.components(separatedBy: " AND ").map { $0.trimmingCharacters(in: .whitespaces) } }

        // Split by "&"
        authors = authors.flatMap { $0.components(separatedBy: "&").map { $0.trimmingCharacters(in: .whitespaces) } }

        // Split by ","
        authors = authors.flatMap { $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }

        // Filter out non-author lines (years, publishers, etc.)
        authors = authors.filter { author in
            let lowercase = author.lowercased()
            // Exclude lines that look like years
            if let _ = Int(author) { return false }
            // Exclude common publisher keywords
            if lowercase.contains("publishing") ||
               lowercase.contains("publisher") ||
               lowercase.contains("press") ||
               lowercase.contains("books") {
                return false
            }
            return true
        }

        return authors
    }

    private func cleanTitle(_ title: String) -> String {
        // Remove common artifacts
        var cleaned = title
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        // Remove trailing punctuation (except ? !)
        if let lastChar = cleaned.last, [".", ",", ";", ":"].contains(lastChar) {
            cleaned = String(cleaned.dropLast())
        }

        return cleaned
    }

    private func extractISBN(from text: String) -> String? {
        // Look for ISBN patterns
        // ISBN-13: 13 digits
        let digitsOnly = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()

        if digitsOnly.count == 13 && isValidISBN13(digitsOnly) {
            return digitsOnly
        }

        return nil
    }

    private func isValidISBN13(_ isbn: String) -> Bool {
        guard isbn.count == 13 else { return false }

        let digits = isbn.compactMap { Int(String($0)) }
        guard digits.count == 13 else { return false }

        // ISBN-13 checksum validation
        // Sum digits at even positions (0, 2, 4, ...)
        let evenSum = stride(from: 0, to: 12, by: 2).reduce(0) { total, index in
            total + digits[index]
        }
        
        // Sum digits at odd positions (1, 3, 5, ...) multiplied by 3
        let oddSum = stride(from: 1, to: 12, by: 2).reduce(0) { total, index in
            total + digits[index] * 3
        }
        
        let sum = evenSum + oddSum
        let checksum = (10 - (sum % 10)) % 10
        return checksum == digits[12]
    }

    // MARK: - Errors

    enum ScannerError: LocalizedError {
        case invalidImage
        case cropFailed
        case encodingFailed
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Failed to process the image"
            case .cropFailed:
                return "Failed to crop the image"
            case .encodingFailed:
                return "Failed to save the image"
            case .noTextFound:
                return "No text could be detected in this image"
            }
        }
    }
}

// MARK: - Platform Image Helpers

private extension PlatformImage {
    var toCGImage: CGImage? {
        #if os(macOS)
        // On macOS, NSImage.cgImage is a method, not a property
        var rect = CGRect(origin: .zero, size: self.size)
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        // On iOS, UIImage.cgImage is a property
        return self.cgImage
        #endif
    }
}

#if os(macOS)
private extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let cgImage = self.toCGImage else { return nil }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
#endif

// MARK: - Camera Availability Check

#if os(iOS)
enum CameraAccess {
    /// Check if camera is available on this device
    static var isAvailable: Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
#else
enum CameraAccess {
    static var isAvailable: Bool {
        return false // macOS not supported in initial implementation
    }
}
#endif
