# iOS Support for tome App

## Context

The tome app is a personal library catalog built for macOS with SwiftUI and SwiftData. The Xcode project is already configured for iOS (and visionOS), but several macOS-only APIs are used that prevent the app from working correctly on iOS. This plan adapts those platform-specific implementations to work on both macOS and iOS without changing any existing macOS layout or functionality.

## Current State

**Project Configuration:**
- iOS target: Already configured (iPhone and iPad)
- Deployment target: 26.2
- Supported platforms: macOS, iOS, visionOS
- Navigation: `NavigationSplitView` (iOS-compatible)

**Platform-Specific Issues:**

1. **Image handling** - `NSImage` is macOS-only
   - `BookCoverView.swift` - Lines 23, 30, 36, 62
   - `ImageCacheService.swift` - Lines 11, 41, 52
   - `UserProfileView.swift` - Line 71
   - `SearchResultRow.swift` - Line 88
   - `AddBookView.swift` - Lines 427, 559, 746, 776

2. **Color handling** - `NSColor` is macOS-only
   - `BookCoverView.swift` - Line 62
   - `SettingsView.swift` - Line 45

3. **Fixed window sizes** - Not ideal for mobile
   - `SettingsView.swift` - Line 44: `.frame(width: 500, height: 450)`

## Implementation Plan

### Phase 1: Platform-Agnostic Image Type

Create a cross-platform image abstraction that works on both macOS and iOS.

**File: `/Users/mmacbook/develop/tome/tome/Models/PlatformImage.swift` (NEW)**

```swift
#if canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#endif

// Helper extensions for creating SwiftUI Images
extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(AppKit)
        self.init(nsImage: platformImage)
        #endif

        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #endif
    }
}

// Helper for initializing PlatformImage from Data
extension PlatformImage {
    init?(data: Data) {
        #if canImport(AppKit)
        self = NSImage(data: data)!
        #endif

        #if canImport(UIKit)
        self = UIImage(data: data)!
        #endif
    }
}
```

### Phase 2: Update BookCoverView

**File: `/Users/mmacbook/develop/tome/tome/Views/Components/BookCoverView.swift`**

Replace `NSImage` with `PlatformImage`:

1. Change import from `import AppKit` to conditional imports
2. Replace `@State private var image: NSImage?` with `PlatformImage?`
3. Replace `Image(nsImage: ...)` with `Image(platformImage: ...)`
4. Replace `NSImage(data: ...)` with `PlatformImage(data: ...)`
5. Replace `Color(nsColor: .separatorColor)` with `.separator` from SwiftUI

### Phase 3: Update ImageCacheService

**File: `/Users/mmacbook/develop/tome/tome/Services/ImageCacheService.swift`**

Replace `NSImage` with `PlatformImage`:

1. Change `import AppKit` to conditional imports
2. Replace `NSCache<NSString, NSImage>` with `NSCache<NSString, PlatformImage>`
3. Replace `fetchImage(url: URL) async throws -> NSImage` return type with `PlatformImage`
4. Replace `NSImage(data: data)` with `PlatformImage(data: data)`

### Phase 4: Update Remaining NSImage Usages

**Files to update:**

1. `/Users/mmacbook/develop/tome/tome/Views/UserProfileView.swift` - Line 71
2. `/Users/mmacbook/develop/tome/tome/Views/Components/SearchResultRow.swift` - Line 88
3. `/Users/mmacbook/develop/tome/tome/Views/AddBookView.swift` - Lines 427, 559, 746, 776

Replace `NSImage` references with `PlatformImage`.

### Phase 5: Update SettingsView for iOS

**File: `/Users/mmacbook/develop/tome/tome/Views/SettingsView.swift`**

1. Replace `.background(Color(nsColor: .windowBackgroundColor))` with `.background(.ultraThinMaterial)` or similar iOS-compatible background
2. Change `.frame(width: 500, height: 450)` to use adaptive sizing:
   - Keep fixed size on macOS with `#if os(macOS)`
   - Use `#if os(iOS)` with flexible frame for mobile

### Phase 6: NavigationRootView iOS Adaptation

**File: `/Users/mmacbook/develop/tome/tome/Views/NavigationRootView.swift`**

`NavigationSplitView` already adapts to iOS, but verify:
- Column widths are appropriate for iPhone
- Three-column layout collapses properly on small screens
- No macOS-specific assumptions

May need to add `#if os(iOS)` conditions for compact navigation patterns.

## Files to Modify

1. **NEW**: `/Users/mmacbook/develop/tome/tome/Models/PlatformImage.swift`
2. `/Users/mmacbook/develop/tome/tome/Views/Components/BookCoverView.swift`
3. `/Users/mmacbook/develop/tome/tome/Services/ImageCacheService.swift`
4. `/Users/mmacbook/develop/tome/tome/Views/UserProfileView.swift`
5. `/Users/mmacbook/develop/tome/tome/Views/Components/SearchResultRow.swift`
6. `/Users/mmacbook/develop/tome/tome/Views/AddBookView.swift`
7. `/Users/mmacbook/develop/tome/tome/Views/SettingsView.swift`
8. `/Users/mmacbook/develop/tome/tome/Views/NavigationRootView.swift` (if needed)

## Verification

1. **Build for iOS Simulator:**
   - Use Xcode to build and run on iPhone simulator
   - Verify no compilation errors

2. **Test Core Functionality:**
   - Book list loads and displays covers
   - Search functionality works
   - Book details display correctly
   - Settings page opens and functions
   - Image caching works

3. **Build for macOS (regression test):**
   - Verify existing macOS functionality is unchanged
   - Confirm layouts, colors, and behavior remain the same

## Key Principles

1. **No macOS behavior changes** - All existing macOS layouts, functionality remain identical
2. **Conditional compilation** - Use `#if canImport()` and `#if os()` for platform-specific code
3. **Type aliases** - Use `PlatformImage` to abstract platform differences
4. **Incremental changes** - Each file is independently testable
