# PlatformColorPicker Usage Guide

## Overview

`PlatformColorPicker` is a cross-platform wrapper that automatically uses:
- **iOS**: Native `ColorPicker` with modal sheet interface
- **macOS**: Custom `ColorSelector` with popover interface

## Quick Start

### Basic Usage

```swift
import SwiftUI

struct MyView: View {
    @State private var selectedColor: Color = .blue
    
    var body: some View {
        Form {
            PlatformColorPicker("Choose Color", selection: $selectedColor)
        }
    }
}
```

### With Opacity Support

```swift
@State private var colorWithAlpha: Color = .red.opacity(0.5)

PlatformColorPicker(
    "Color with Opacity",
    selection: $colorWithAlpha,
    supportsOpacity: true
)
```

### Without Opacity (Opaque Colors Only)

```swift
@State private var opaqueColor: Color = .purple

PlatformColorPicker(
    "Opaque Color",
    selection: $opaqueColor,
    supportsOpacity: false
)
```

## Working with Hex Strings (Tags)

### Converting Between Color and Hex

```swift
@State private var tagColorHex: String = "#007AFF"

PlatformColorPicker(
    "Tag Color",
    selection: Binding(
        get: { Color(hex: tagColorHex) ?? .blue },
        set: { tagColorHex = $0.toHex() }
    ),
    supportsOpacity: false
)
```

### Updated TagColorPicker

The `TagColorPicker` in `TagCloudView.swift` has been updated to include an optional custom color picker:

```swift
// Show preset colors only
TagColorPicker(selectedColor: $tagColorHex, showCustomColorPicker: false)

// Show preset colors + custom picker
TagColorPicker(selectedColor: $tagColorHex, showCustomColorPicker: true)
```

## macOS-Specific Usage

On macOS, you can also use NSColor bindings:

```swift
#if os(macOS)
@State private var nsColor: NSColor = .systemBlue

PlatformColorPicker(
    "macOS Color",
    nsColor: $nsColor,
    supportsOpacity: false
)
#endif
```

## Integration Examples

### In a Settings View

```swift
struct SettingsView: View {
    @State private var accentColor: Color = .blue
    
    var body: some View {
        Form {
            Section("Appearance") {
                PlatformColorPicker(
                    "Accent Color",
                    selection: $accentColor,
                    supportsOpacity: false
                )
            }
        }
    }
}
```

### In a Tag Editor

```swift
struct TagEditorView: View {
    @State private var tagName: String = ""
    @State private var tagColorHex: String = "#007AFF"
    
    var body: some View {
        Form {
            Section("Tag Details") {
                TextField("Name", text: $tagName)
                
                PlatformColorPicker(
                    "Color",
                    selection: Binding(
                        get: { Color(hex: tagColorHex) ?? .blue },
                        set: { tagColorHex = $0.toHex() }
                    ),
                    supportsOpacity: false
                )
            }
            
            Section("Preview") {
                Text(tagName)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: tagColorHex) ?? .blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}
```

### In a Theme Customizer

```swift
struct ThemeCustomizer: View {
    @State private var primaryColor: Color = .blue
    @State private var secondaryColor: Color = .green
    @State private var backgroundColor: Color = .white
    
    var body: some View {
        Form {
            Section("Colors") {
                PlatformColorPicker("Primary", selection: $primaryColor)
                PlatformColorPicker("Secondary", selection: $secondaryColor)
                PlatformColorPicker("Background", selection: $backgroundColor)
            }
            
            Section("Preview") {
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(primaryColor)
                        .frame(height: 60)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(secondaryColor)
                        .frame(height: 60)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                        .frame(height: 60)
                }
            }
        }
    }
}
```

## Color Extension Methods

The following extension methods are available:

### Color.init(hex:)
```swift
let color = Color(hex: "#007AFF")
```

### Color.toHex()
```swift
let hexString = Color.blue.toHex()  // Returns "#007AFF"
```

## Platform Behavior

### iOS
- Uses native `ColorPicker` from SwiftUI
- Opens in a modal sheet
- Includes eyedropper tool and color grid
- Supports opacity slider when enabled

### macOS
- Uses custom `ColorSelector` from ColorSelector package
- Opens in a popover
- Includes HSB color wheel, brightness slider, and alpha slider
- Matches native macOS design patterns

## Migration Guide

### If you were using ColorSelector directly:

**Before:**
```swift
ColorSelector(selection: $color)
    .showsAlpha(false)
```

**After:**
```swift
PlatformColorPicker(selection: $color, supportsOpacity: false)
```

### If you were using native ColorPicker:

**Before:**
```swift
#if os(iOS)
ColorPicker("Color", selection: $color)
#elseif os(macOS)
// Custom implementation
#endif
```

**After:**
```swift
PlatformColorPicker("Color", selection: $color)
```

## Files Modified

1. **PlatformColorPicker.swift** (new) - Main wrapper component
2. **TagCloudView.swift** (modified) - Updated `TagColorPicker` to support custom colors
3. **PlatformColorPickerExamples.swift** (new) - Comprehensive examples

## Notes

- The wrapper automatically detects the platform at compile time using conditional compilation
- No runtime overhead - the unused platform code is not included in the final binary
- Maintains the same interface across platforms for easy code sharing
- The `supportsOpacity` parameter maps to `showsAlpha` on macOS
