import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Camera view for capturing book covers
#if os(iOS)
struct BookCoverCameraView: View {
    @Binding var capturedImageData: Data?
    @Environment(\.dismiss) private var dismiss

    @State private var showPicker = true

    var body: some View {
        NavigationStack {
            Color.clear
                .fullScreenCover(isPresented: $showPicker, onDismiss: {
                    dismiss()
                }) {
                    ImagePicker { image in
                        processCapturedImage(image)
                    }
                }
        }
    }

    private func processCapturedImage(_ image: UIImage) {
        Task {
            do {
                // Convert to PlatformImage
                guard let cgImage = image.cgImage else {
                    capturedImageData = image.jpegData(compressionQuality: 0.85)
                    dismiss()
                    return
                }

                let platformImage = PlatformImage(cgImage: cgImage)

                // Detect rectangles for auto-cropping
                let rectangles = try await BookCoverScanner.shared.detectRectangles(in: platformImage)

                if let bestRectangle = rectangles.first {
                    // Crop to the best rectangle
                    let croppedData = try await BookCoverScanner.shared.cropImage(platformImage, to: bestRectangle)
                    capturedImageData = croppedData
                } else {
                    // No rectangle detected, use full image
                    let fullImageData = image.jpegData(compressionQuality: 0.85)
                    capturedImageData = fullImageData
                }

                dismiss()
            } catch {
                // If detection fails, still use the full image
                let fullImageData = image.jpegData(compressionQuality: 0.85)
                capturedImageData = fullImageData
                dismiss()
            }
        }
    }
}

// MARK: - Image Picker

/// UIKit image picker wrapper
struct ImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#else
// macOS placeholder - not supported
struct BookCoverCameraView: View {
    @Binding var capturedImageData: Data?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.metering.matrix")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Camera Not Available on macOS")
                .font(.title2.bold())

            Text("The camera feature is currently only available on iOS devices.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("OK") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
#endif
