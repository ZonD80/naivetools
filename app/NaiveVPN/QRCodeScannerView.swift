import AVFoundation
import SwiftUI

struct QRCodeScannerSheet: View {
    let onCodeScanned: (String) -> Void
    let onFailure: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                QRCodeScannerView(
                    onCodeScanned: { payload in
                        onCodeScanned(payload)
                        dismiss()
                    },
                    onFailure: { message in
                        onFailure(message)
                        dismiss()
                    }
                )
                .ignoresSafeArea()

                Text(L10n.tr("Center the QR code inside the camera view."))
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
            .navigationTitle(L10n.tr("Scan QR Code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned, onFailure: onFailure)
    }

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let viewController = QRCodeScannerViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}

    final class Coordinator: NSObject, QRCodeScannerViewControllerDelegate {
        private let onCodeScanned: (String) -> Void
        private let onFailure: (String) -> Void

        init(onCodeScanned: @escaping (String) -> Void, onFailure: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
            self.onFailure = onFailure
        }

        func qrCodeScannerViewController(_ controller: QRCodeScannerViewController, didCapture code: String) {
            onCodeScanned(code)
        }

        func qrCodeScannerViewController(_ controller: QRCodeScannerViewController, didFail message: String) {
            onFailure(message)
        }
    }
}

protocol QRCodeScannerViewControllerDelegate: AnyObject {
    func qrCodeScannerViewController(_ controller: QRCodeScannerViewController, didCapture code: String)
    func qrCodeScannerViewController(_ controller: QRCodeScannerViewController, didFail message: String)
}

final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRCodeScannerViewControllerDelegate?

    private let session = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private var isConfigured = false
    private var didReportResult = false

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        configureSessionIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if isConfigured, !session.isRunning {
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else {
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }

                    if granted {
                        self.configureSession()
                    } else {
                        self.delegate?.qrCodeScannerViewController(self, didFail: L10n.tr("Camera access was denied."))
                    }
                }
            }
        default:
            delegate?.qrCodeScannerViewController(self, didFail: L10n.tr("Camera access is unavailable."))
        }
    }

    private func configureSession() {
        guard !isConfigured else {
            return
        }

        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.qrCodeScannerViewController(self, didFail: L10n.tr("No camera is available on this device."))
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            let metadataOutput = AVCaptureMetadataOutput()

            session.beginConfiguration()

            guard session.canAddInput(input), session.canAddOutput(metadataOutput) else {
                session.commitConfiguration()
                delegate?.qrCodeScannerViewController(self, didFail: L10n.tr("Unable to configure the QR scanner."))
                return
            }

            session.addInput(input)
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]

            session.commitConfiguration()

            previewLayer.session = session
            isConfigured = true
            session.startRunning()
        } catch {
            delegate?.qrCodeScannerViewController(self, didFail: L10n.tr("Unable to start the camera."))
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didReportResult else {
            return
        }

        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            object.type == .qr,
            let payload = object.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
            !payload.isEmpty
        else {
            return
        }

        didReportResult = true
        session.stopRunning()
        delegate?.qrCodeScannerViewController(self, didCapture: payload)
    }
}
