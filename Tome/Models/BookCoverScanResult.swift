import Foundation

/// Result of scanning a book cover with Vision framework
struct BookCoverScanResult {
    let croppedImageData: Data
    let originalRectangle: DetectedRectangle
    let ocrResult: OCRResult?
    let barcodeResult: String?
}

/// Detected rectangle from Vision framework
struct DetectedRectangle {
    let boundingBox: CGRect  // Normalized coordinates (0-1)
    let confidence: Float
}

/// OCR text extraction result
struct OCRResult {
    let text: String
    let confidence: Float
}

/// Book information extracted from OCR and barcode detection
struct BookInfo {
    let title: String
    let authors: [String]
    let isbn: String?
    let confidence: Float
}
