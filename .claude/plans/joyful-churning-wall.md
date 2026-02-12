# Fix macOS Build Errors - iOS to macOS Migration

## Context

The initial implementation was designed for iOS using UIKit and iOS-specific APIs, but the project is actually a macOS app. This has caused build failures because:
- UIKit types (UIImage, UIColor) don't exist on macOS
- iOS-specific color references don't work on macOS
- @ObservedObject is incompatible with @Observable ViewModels (should use @Bindable)

**Goal**: Fix all remaining iOS-to-macOS compatibility issues to achieve a successful build.

## Files to Modify

### 1. tome/Views/AddBookView.swift (3 changes)

**Line 100**: Change iOS color to macOS color
```swift
// Before:
Color(uiColor: .systemGray6)

// After:
Color(nsColor: .controlBackgroundColor)
```

**Line 228**: Change @ObservedObject to @Bindable for @Observable ViewModel
```swift
// Before:
@ObservedObject var viewModel: BookSearchViewModel

// After:
@Bindable var viewModel: BookSearchViewModel
```

**Line 295**: Change UIImage to NSImage
```swift
// Before:
@State private var coverImage: UIImage?

// After:
@State private var coverImage: NSImage?
```

### 2. tome/Views/LibraryListView.swift (1 change)

**Line 151**: Change @ObservedObject to @Bindable for @Observable ViewModel
```swift
// Before:
@ObservedObject var viewModel: LibraryViewModel

// After:
@Bindable var viewModel: LibraryViewModel
```

### 3. tome/Views/Components/ReadingStatusPicker.swift (1 change)

**Line 32**: Change iOS color to macOS color
```swift
// Before:
.background(selectedStatus == status ? status.color.opacity(0.2) : Color(.systemGray6))

// After:
.background(selectedStatus == status ? status.color.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
```

## Implementation Steps

1. **Fix AddBookView.swift**
   - Edit line 100: Replace `Color(uiColor: .systemGray6)` with `Color(nsColor: .controlBackgroundColor)`
   - Edit line 228: Replace `@ObservedObject` with `@Bindable`
   - Edit line 295: Replace `UIImage` with `NSImage`

2. **Fix LibraryListView.swift**
   - Edit line 151: Replace `@ObservedObject` with `@Bindable`

3. **Fix ReadingStatusPicker.swift**
   - Edit line 32: Replace `Color(.systemGray6)` with `Color(nsColor: .controlBackgroundColor)`

4. **Verify build**
   - Run: `xcodebuild -project /Users/mmacbook/develop/tome/tome.xcodeproj -scheme tome -destination 'platform=macOS' build`
   - Confirm: "BUILD SUCCEEDED"

## Technical Notes

### Why @Bindable instead of @ObservedObject?
- The ViewModels use the modern `@Observable` macro (Swift 5.9+)
- `@Observable` classes are incompatible with `@ObservedObject`
- `@Bindable` is the correct property wrapper for binding to `@Observable` classes in SwiftUI views
- Reference: [SwiftUI @Observable documentation](https://developer.apple.com/documentation/swiftui/observable)

### macOS Color Mapping
- iOS `UIColor.systemGray6` → macOS `NSColor.controlBackgroundColor`
- Using `Color(nsColor:)` initializer creates SwiftUI color from AppKit color
- This provides the native macOS appearance for text input backgrounds

## Verification

After making these changes:

1. **Build the project**
   ```bash
   xcodebuild -project tome.xcodeproj -scheme tome -destination 'platform=macOS' build
   ```

2. **Expected outcome**: BUILD SUCCEEDED with no errors

3. **Additional checks** (optional):
   - No remaining references to `UIKit`, `UIImage`, `UIColor` in the Views directory
   - No remaining uses of `@ObservedObject` with `@Observable` ViewModels
   - All color references use macOS equivalents

## Files Already Correct (No Changes Needed)

- ✅ `tome/Views/BookDetailView.swift` - Already migrated to macOS
- ✅ `tome/Views/Components/SearchResultRow.swift` - Already migrated
- ✅ `tome/ViewModels/BookDetailViewModel.swift` - Uses @Observable correctly
- ✅ `tome/ViewModels/BookSearchViewModel.swift` - Uses @Observable correctly
- ✅ `tome/ViewModels/LibraryViewModel.swift` - Uses @Observable correctly
- ✅ `tome/Services/ImageCacheService.swift` - Already uses AppKit
- ✅ `tome/Views/Components/BookCoverView.swift` - Already uses AppKit
