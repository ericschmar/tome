import SwiftUI

/// Visual tag display component
struct TagCloudView: View {
    let tags: [Tag]
    var isEditable = false
    var onTagTap: ((Tag) -> Void)?
    var onAddTag: (() -> Void)?

    @State private var totalHeight = CGFloat.zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty || isEditable {
                if isEditable {
                    HStack {
                        Text("Tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Add", action: onAddTag ?? {})
                            .font(.caption)
                    }
                }

                GeometryReader { geometry in
                    generateTags(in: geometry)
                }
                .frame(height: totalHeight)
            } else {
                Text("No tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func generateTags(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(tags) { tag in
                TagChip(tag: tag, isEditable: isEditable, onTap: {
                    onTagTap?(tag)
                })
                .padding(.trailing, 4)
                .padding(.bottom, 4)
                .alignmentGuide(.leading) { dimension in
                    if abs(width - dimension.width) > geometry.size.width {
                        width = 0
                        height -= dimension.height
                    }
                    let result = width
                    if tag == tags.last {
                        width = 0
                    } else {
                        width -= dimension.width
                    }
                    return result
                }
                .alignmentGuide(.top) { dimension in
                    let result = height
                    if tag == tags.last {
                        height = 0
                    }
                    return result
                }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geometry.size.height
            }
            return .clear
        }
    }
}

/// Individual tag chip
struct TagChip: View {
    let tag: Tag
    var isEditable = false
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 4) {
                if isEditable {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
                Text(tag.name)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tagColor)
            .foregroundStyle(textColor)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private var tagColor: Color {
        Color(hex: tag.colorHex) ?? .blue
    }

    private var textColor: Color {
        // Determine if we should use white or black text based on background luminance
        isLightColor(hex: tag.colorHex) ? .primary : .white
    }

    private func isLightColor(hex: String) -> Bool {
        // Simple luminance check - refined colors should be treated as light
        let hexClean = hex.replacingOccurrences(of: "#", with: "")
        guard hexClean.count == 6 else { return false }

        let scanner = Scanner(string: hexClean)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return false }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        // Relative luminance formula
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6
    }
}

/// Color picker for creating new tags
struct TagColorPicker: View {
    @Binding var selectedColor: String
    var showCustomColorPicker: Bool = true

    private let colors: [String] = [
        // Refined palette - softer, more sophisticated colors
        "#5E5CE6", // Soft indigo
        "#007AFF", // Classic blue
        "#5856D6", // Purple
        "#AF52DE", // Soft purple
        "#FF2D55", // Soft red
        "#FF375F", // Berry
        "#FF9F0A", // Warm orange
        "#FFD60A", // Muted yellow
        "#30D158", // Soft green
        "#32D74B", // Green
        "#64D2FF", // Light blue
        "#0A84FF", // Clear blue
        "#5AC8FA", // Cyan
        "#BF5AF2", // Soft violet
        "#FF6482", // Soft pink
        "#8E8E93"  // Neutral gray
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Preset colors grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(Color(hex: color) ?? .blue)
                        .frame(width: 30, height: 30)
                        .overlay {
                            if selectedColor == color {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                                    .frame(width: 26, height: 26)
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture {
                            selectedColor = color
                        }
                }
            }
            
            // Custom color picker (platform-adaptive)
            if showCustomColorPicker {
                Divider()
                    .padding(.vertical, 4)
                
                PlatformColorPicker(
                    "Custom Color",
                    selection: Binding(
                        get: {
                            Color(hex: selectedColor) ?? .blue
                        },
                        set: { newColor in
                            selectedColor = newColor.toHex()
                        }
                    ),
                    supportsOpacity: false
                )
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading) {
            Text("Tag Cloud (Read-only)")
                .font(.headline)
            TagCloudView(tags: [
                Tag(name: "Fiction", colorHex: "#007AFF"),
                Tag(name: "Science Fiction", colorHex: "#5856D6"),
                Tag(name: "Classic", colorHex: "#FF9F0A"),
                Tag(name: "Favorite", colorHex: "#FF375F")
            ])
        }

        VStack(alignment: .leading) {
            Text("Tag Cloud (Editable)")
                .font(.headline)
            TagCloudView(
                tags: [
                    Tag(name: "Fiction", colorHex: "#007AFF"),
                    Tag(name: "Science Fiction", colorHex: "#5856D6")
                ],
                isEditable: true,
                onAddTag: { print("Add tag") }
            )
        }

        VStack(alignment: .leading) {
            Text("Color Picker (Preset Only)")
                .font(.headline)
            TagColorPicker(selectedColor: .constant("#007AFF"), showCustomColorPicker: false)
        }
        
        VStack(alignment: .leading) {
            Text("Color Picker (With Custom)")
                .font(.headline)
            TagColorPicker(selectedColor: .constant("#007AFF"), showCustomColorPicker: true)
        }
    }
    .padding()
}
