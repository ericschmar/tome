# Camera-Based Book Cover Capture with OCR and Barcode Detection

## Context

This feature enhances the manual book entry flow by allowing users to capture book covers using their device camera, automatically crop to the book cover, and extract title/author information using Apple's Vision framework for:
- Rectangle detection (auto-cropping)
- OCR text recognition (title/author extraction)
- Barcode/ISBN detection (fallback lookup)

This streamlines manual book entry, reducing typing and improving accuracy.

## User Flow

1. User opens AddBookView → Manual Entry tab
2. Taps cover image placeholder
3. Selects "Take Photo" from menu
4. Camera viewfinder opens with real-time book detection overlay
5. User positions book, captures photo
6. Photo is auto-cropped to detected book cover
7. Returns to manual entry with cropped image displayed
8. Button appears: "Auto-fill title and author from this photo?"
9. User taps button → app extracts title/author via OCR + barcode
10. Form fields are populated with extracted data
11. User can edit before saving

## Scope Decisions

- **Platform**: iOS only initially (UIImagePickerController simplicity)
- **Barcode Detection**: ✅ Included in initial implementation
- **Image Storage**: Store cropped image only (saves space)
- **OCR Fallback**: Show error message if parsing fails (cleaner UX)

## Files to Create

### 1. `Tome/Services/BookCoverScanner.swift`
**Vision framework wrapper service**

**Responsibilities**:
- Rectangle detection for auto-cropping
- OCR text extraction (title/author)
- Barcode/ISBN detection
- Text parsing to identify title vs author
- Image cropping to detected rectangle

**Key Methods**:
```swift
@MainActor
@Observable
final class BookCoverScanner {
    static let shared = BookCoverScanner()

    // Detect rectangles in image (for auto-cropping)
    func detectRectangles(in image: PlatformImage) async throws -> [DetectedRectangle]

    // Crop image to detected rectangle
    func cropImage(_ image: PlatformImage, to rectangle: DetectedRectangle) async throws -> Data

    // Extract text via OCR
    func extractText(from image: PlatformImage) async throws -> OCRResult

    // Detect barcode/ISBN
    func detectBarcode(from image: PlatformImage) async throws -> String?

    // Parse title and author from OCR text
    func parseBookInfo(from text: String) -> BookInfo?
}

struct DetectedRectangle {
    let boundingBox: CGRect  // Normalized coordinates
    let confidence: Float
}

struct OCRResult {
    let text: String
    let confidence: Float
}

struct BookInfo {
    let title: String
    let authors: [String]
    let isbn: String?
    let confidence: Float
}
```

**Implementation Notes**:
- Use `@MainActor` and `@Observable` to match existing service pattern
- Rectangle detection: `VNDetectRectanglesRequest` with min/max aspect ratio for books
- OCR: `VNRecognizeTextRequest` with `.accurate` level and language correction
- Barcode: `VNDetectBarcodesRequest` filtering for EAN-13 (ISBN)
- Text parsing heuristics:
  - First line = title (usually largest/boldest)
  - Look for "by" keyword to identify author
  - Second line = author if no "by" found
  - Split authors by "and", "&", comma

### 2. `Tome/Views/BookCoverCameraView.swift`
**Camera viewfinder with real-time detection**

**Responsibilities**:
- Display live camera feed
- Real-time rectangle detection overlay
- Capture controls (shutter, cancel, flash)
- Permission handling

**Key Properties**:
```swift
struct BookCoverCameraView: View {
    @Binding var capturedImage: Data?
    @Environment(\.dismiss) private var dismiss

    @StateObject private var scanner = BookCoverScanner.shared
    @State private var isCameraAuthorized = false
    @State private var detectedRectangles: [DetectedRectangle] = []
    @State private var selectedRectangle: DetectedRectangle?
    @State private var isFlashOn = false

    var body: some View { ... }
}
```

**UI Layout**:
- Full-screen camera preview
- Semi-transparent overlay with detected rectangles drawn in green/yellow
- Bottom controls bar: Cancel (left), Shutter (center), Flash (right)
- Guidance text: "Position book cover in frame"
- Rectangle confidence indicator (color changes based on detection quality)

**Key Behaviors**:
- Process frames at ~15 FPS (avoid UI jank)
- Highlight best rectangle (highest confidence, ~0.6-0.75 aspect ratio)
- Auto-select rectangle when confidence > 0.8
- Flash/torch toggle if hardware supports it

### 3. `Tome/Models/BookCoverScanResult.swift`
**Scan result data model**

```swift
struct BookCoverScanResult {
    let croppedImageData: Data
    let originalRectangle: DetectedRectangle
    let ocrResult: OCRResult?
    let barcodeResult: String?
}
```

## Files to Modify

### 1. `Tome/Views/AddBookView.swift`
**Integrate camera option and OCR button**

**Changes**:

#### A. Add new state properties (top of AddBookManualView)
```swift
@State private var showingCamera = false
@State private var showingOCRProgress = false
@State private var ocrError: String?
@State private var scanResult: BookCoverScanResult?
```

#### B. Add "Take Photo" menu item (line 499, before "Choose from Photos")
```swift
Menu {
    // NEW: Camera option
    Button {
        showingCamera = true
    } label: {
        Label("Take Photo", systemImage: "camera.viewfinder")
    }
    .disabled(!CameraAccess.isAvailable)

    Button {
        showingImagePicker = true
    } label: {
        Label("Choose from Photos", systemImage: "photo.on.rectangle")
    }

    // ... rest of menu
}
```

#### C. Add OCR button (after line 588, below hint text)
```swift
// NEW: OCR prompt button
if coverImageData != nil && (title.isEmpty || authors.isEmpty) {
    Button {
        Task { await performOCR() }
    } label: {
        HStack(spacing: 8) {
            Image(systemName: "text.viewfinder")
            Text("Auto-fill title and author from this photo?")
        }
        .font(.caption)
        .foregroundStyle(.blue)
    }
    .buttonStyle(.borderless)
    .disabled(showingOCRProgress)
}

// NEW: OCR progress
if showingOCRProgress {
    HStack(spacing: 8) {
        ProgressView()
            .controlSize(.small)
        Text("Extracting text...")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// NEW: OCR error
if let error = ocrError {
    HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
        Text(error)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    .padding(8)
    .background(Color.orange.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 6))
}
```

#### D. Add camera sheet modifier (after line 625)
```swift
.sheet(isPresented: $showingCamera) {
    BookCoverCameraView(capturedImage: $coverImageData)
}
```

#### E. Add OCR handler method (after handleImageSelection)
```swift
private func performOCR() async {
    showingOCRProgress = true
    ocrError = nil

    guard let imageData = coverImageData,
          let platformImage = PlatformImage.from(data: imageData) else {
        ocrError = "Failed to load image"
        showingOCRProgress = false
        return
    }

    do {
        // Try barcode/ISBN detection first (faster, more accurate)
        if let isbn = try await BookCoverScanner.shared.detectBarcode(from: platformImage) {
            await lookupBookByISBN(isbn)
            showingOCRProgress = false
            return
        }

        // Fallback to OCR
        let ocrResult = try await BookCoverScanner.shared.extractText(from: platformImage)

        if let bookInfo = BookCoverScanner.shared.parseBookInfo(from: ocrResult.text) {
            await MainActor.run {
                title = bookInfo.title
                authors = bookInfo.authors.joined(separator: ", ")
                if let isbn = bookInfo.isbn {
                    self.isbn = isbn
                }
                showingOCRProgress = false
            }
        } else {
            await MainActor.run {
                ocrError = "Could not detect title and author. Please enter manually."
                showingOCRProgress = false
            }
        }
    } catch {
        await MainActor.run {
            ocrError = "Failed to extract text: \(error.localizedDescription)"
            showingOCRProgress = false
        }
    }
}

private func lookupBookByISBN(_ isbn: String) async {
    // Use existing OpenLibraryService to fetch book by ISBN
    // Populate form fields with fetched data
}
```

### 2. `Tome/Info.plist`
**Add camera usage description**

```xml
<key>NSCameraUsageDescription</key>
<string>Tome needs camera access to scan book covers for automatic text extraction and ISBN detection.</string>
```

## Implementation Steps

### Step 1: Create BookCoverScanner service
1. Create `Tome/Services/BookCoverScanner.swift`
2. Implement `detectRectangles()` using `VNDetectRectanglesRequest`
3. Implement `cropImage()` to convert Vision coordinates to CoreImage crop
4. Implement `detectBarcode()` using `VNDetectBarcodesRequest`
5. Implement `extractText()` using `VNRecognizeTextRequest`
6. Implement `parseBookInfo()` with heuristics for title/author separation
7. Add comprehensive error handling with user-friendly messages

### Step 2: Create BookCoverCameraView
1. Create `Tome/Views/BookCoverCameraView.swift`
2. Set up `UIImagePickerController` for camera capture
3. Add real-time rectangle detection using AVCaptureVideoDataOutput
4. Implement overlay drawing for detected rectangles
5. Add capture controls (shutter, cancel, flash)
6. Handle camera permissions gracefully
7. Auto-crop captured image to best rectangle before returning

### Step 3: Integrate with AddBookView
1. Add "Take Photo" menu item to cover image menu
2. Add camera sheet presentation
3. Add OCR prompt button below cover preview
4. Implement `performOCR()` method with barcode + OCR fallback
5. Add loading state and error handling for OCR
6. Connect ISBN lookup using existing OpenLibraryService

### Step 4: Testing and refinement
1. Test camera capture with various book covers
2. Test rectangle detection accuracy
3. Test OCR text extraction with different fonts/layouts
4. Test barcode/ISBN detection
5. Test error states (no camera, permission denied, no text detected)
6. Performance optimization (frame rate, memory, battery)

## Text Parsing Heuristics

**Title Identification**:
- First non-empty line (typically largest/prominent)
- Longest line if title spans multiple lines
- Uppercase or mixed case (not all lowercase)

**Author Identification**:
- Look for "by", "by the author" keywords
- Second or third line if no "by" found
- Split by "and", "&", "," for multiple authors
- Exclude lines with numeric years, publishers

**ISBN Detection**:
- Filter for EAN-13 barcode format
- Validate ISBN-13 checksum
- Return as string for OpenLibrary lookup

**Confidence Scoring**:
- High confidence: Barcode detected (>0.95)
- Medium confidence: Clear title + author separated (>0.7)
- Low confidence: Text found but parsing ambiguous (<0.5)

## Error Handling

**Camera Access Denied**:
- Show alert: "Camera access is needed to scan book covers"
- Offer to open Settings app
- Fall back to photo picker option

**No Rectangle Detected**:
- Use full image instead of cropping
- Inform user: "Couldn't detect book cover, using full image"
- Continue with OCR on full image

**OCR Fails**:
- Show error: "Couldn't read text from this image"
- Suggest: "Try retaking the photo in better lighting"
- Keep captured image for manual entry

**Barcode Detected, Lookup Fails**:
- Show partial success message
- Still offer OCR as fallback
- Display ISBN in form for manual entry

**Parsing Fails**:
- Show error: "Could not detect title and author"
- Don't auto-fill (avoid wrong data)
- User can still manually enter or retry

## Performance Considerations

**Camera**:
- Process frames at 15 FPS (not 60 FPS)
- Use `minFrameDuration` to throttle AVCaptureVideoDataOutput
- Stop processing when sheet dismissed

**Vision Framework**:
- Rectangle detection: `maximumObservations = 10`, `minimumConfidence = 0.6`
- OCR: Use `.fast` first, fallback to `.accurate` if needed
- Limit OCR region to detected rectangle (not full image)
- Add 15s timeout for all Vision requests

**Memory**:
- Release camera resources in `.deinit`
- Use `autoreleasepool` for Vision processing
- Limit image size to ~500KB when storing

**Battery**:
- Stop detection when not actively viewing camera
- Provide manual capture (don't force continuous processing)
- Disable flash by default

## Dependencies

**System Frameworks** (all available on iOS 18.6+):
- `AVFoundation` - Camera capture
- `Vision` - Rectangle detection, OCR, barcode detection
- `CoreImage` - Image cropping
- `UIKit` - UIImagePickerController

**No External Dependencies** - All functionality provided by Apple frameworks

## Verification

**Manual Testing**:
1. Open AddBookView → tap cover placeholder → verify "Take Photo" appears
2. Tap "Take Photo" → verify camera opens with permission prompt
3. Point at book → verify green rectangle outline appears
4. Capture photo → verify cropped image displays in form
5. Verify "Auto-fill" button appears below image
6. Tap "Auto-fill" → verify loading indicator shows
7. Verify title and author fields populate correctly
8. Test with barcode: verify ISBN lookup works
9. Test without barcode: verify OCR fallback works
10. Test in low light: verify helpful error message
11. Test with text in foreign language: verify graceful failure
12. Edit auto-filled fields → verify edits persist
13. Save book → verify cropped image stored correctly
14. View saved book in library → verify cover displays

**Unit Tests** (optional but recommended):
- Test rectangle detection with sample images
- Test cropping with various rectangle coordinates
- Test OCR with different fonts and layouts
- Test text parsing with real book data
- Test barcode detection with ISBN images
- Test error handling for permission denial

## Future Enhancements (Out of Scope)

- macOS camera support (AVFoundation on macOS 15.6+)
- Multiple capture angles (stitch for better OCR)
- Custom CoreML model for better book detection
- Batch capture (multiple books in one session)
- VoiceOver guidance for positioning
- Haptic feedback when rectangle detected
