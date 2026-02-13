//
//  PlatformColorPicker.swift
//  tome
//
//  A cross-platform color picker wrapper that uses native iOS ColorPicker
//  on iOS and the custom ColorSelector on macOS.
//

import SwiftUI
#if os(macOS)
import ColorSelector
#endif

/// A cross-platform color picker that adapts to the platform
struct PlatformColorPicker: View {
    let title: LocalizedStringKey?
    @Binding var selection: Color
    let supportsOpacity: Bool
    
    init(
        _ title: LocalizedStringKey? = nil,
        selection: Binding<Color>,
        supportsOpacity: Bool = true
    ) {
        self.title = title
        self._selection = selection
        self.supportsOpacity = supportsOpacity
    }
    
    var body: some View {
        #if os(iOS)
        // Use native iOS ColorPicker
        ColorPicker(
            title ?? "Color",
            selection: $selection,
            supportsOpacity: supportsOpacity
        )
        #elseif os(macOS)
        // Use custom ColorSelector on macOS
        HStack {
            if let title {
                Text(title)
            }
            Spacer()
            ColorSelector(
                selection: Binding(
                    get: { selection },
                    set: { selection = $0 ?? .blue }
                )
            )
            .showsAlpha(supportsOpacity)
        }
        #endif
    }
}

/// Convenience extension for nullable Color bindings
extension PlatformColorPicker {
    init(
        _ title: LocalizedStringKey? = nil,
        selection: Binding<Color?>,
        supportsOpacity: Bool = true
    ) {
        self.title = title
        self._selection = Binding(
            get: { selection.wrappedValue ?? .blue },
            set: { selection.wrappedValue = $0 }
        )
        self.supportsOpacity = supportsOpacity
    }
}

#if os(macOS)
/// Extension for NSColor bindings (macOS only)
extension PlatformColorPicker {
    init(
        _ title: LocalizedStringKey? = nil,
        nsColor: Binding<NSColor>,
        supportsOpacity: Bool = true
    ) {
        self.title = title
        self._selection = Binding(
            get: { Color(nsColor: nsColor.wrappedValue) },
            set: { nsColor.wrappedValue = NSColor($0) }
        )
        self.supportsOpacity = supportsOpacity
    }
    
    init(
        _ title: LocalizedStringKey? = nil,
        nsColor: Binding<NSColor?>,
        supportsOpacity: Bool = true
    ) {
        self.title = title
        self._selection = Binding(
            get: { 
                if let nsColor = nsColor.wrappedValue {
                    return Color(nsColor: nsColor)
                } else {
                    return .blue
                }
            },
            set: { nsColor.wrappedValue = NSColor($0) }
        )
        self.supportsOpacity = supportsOpacity
    }
}
#endif

// MARK: - Preview

#Preview("Platform Color Picker") {
    struct PreviewWrapper: View {
        @State private var color: Color = .blue
        @State private var colorWithOpacity: Color = .red.opacity(0.5)
        
        var body: some View {
            Form {
                Section("Basic Color Picker") {
                    PlatformColorPicker("Choose Color", selection: $color)
                }
                
                Section("With Opacity") {
                    PlatformColorPicker(
                        "Choose Color with Opacity",
                        selection: $colorWithOpacity,
                        supportsOpacity: true
                    )
                }
                
                Section("Without Opacity") {
                    PlatformColorPicker(
                        "Choose Opaque Color",
                        selection: $color,
                        supportsOpacity: false
                    )
                }
                
                Section("Preview") {
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color)
                            .frame(width: 60, height: 40)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorWithOpacity)
                            .frame(width: 60, height: 40)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 500)
        }
    }
    
    return PreviewWrapper()
}
