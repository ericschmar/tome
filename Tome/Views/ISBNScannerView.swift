import SwiftUI

#if os(iOS)
import AVFoundation

// MARK: - Sheet wrapper

struct ISBNScannerSheet: View {
    let onISBNScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var didScan = false

    var body: some View {
        NavigationStack {
            ZStack {
                ISBNScannerRepresentable { isbn in
                    guard !didScan else { return }
                    didScan = true
                    onISBNScanned(isbn)
                    dismiss()
                }
                .ignoresSafeArea()

                // Viewfinder overlay
                VStack(spacing: 16) {
                    Spacer()

                    ZStack {
                        // Dimming outside the target area
                        Color.black.opacity(0.45)
                            .mask(
                                Rectangle()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .frame(width: 260, height: 110)
                                            .blendMode(.destinationOut)
                                    )
                            )

                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                            .frame(width: 260, height: 110)
                    }
                    .ignoresSafeArea()

                    Text("Align barcode within the frame")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .shadow(radius: 4)

                    Spacer()
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - UIViewControllerRepresentable

private struct ISBNScannerRepresentable: UIViewControllerRepresentable {
    let onISBNScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ISBNScannerViewController {
        let vc = ISBNScannerViewController()
        vc.onISBNScanned = onISBNScanned
        return vc
    }

    func updateUIViewController(_ uiViewController: ISBNScannerViewController, context: Context) {}
}

// MARK: - UIKit camera controller

final class ISBNScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onISBNScanned: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        output.setMetadataObjectsDelegate(self, queue: .main)
        // EAN-13 covers ISBN-13; EAN-8 covers short barcodes
        output.metadataObjectTypes = [.ean13, .ean8]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        captureSession = session
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }

        captureSession?.stopRunning()
        onISBNScanned?(value)
    }
}
#endif
