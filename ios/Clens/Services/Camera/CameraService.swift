import Foundation
@preconcurrency import AVFoundation

// Camera session used by ScanView. Manages permission, live barcode
// detection via AVCaptureMetadataOutput, and still-image capture via
// AVCapturePhotoOutput for label/receipt flows. SwiftUI observes via
// @Published properties.
//
// AVFoundation types aren't Sendable, so the class itself is not MainActor;
// all UI-visible state mutation hops back to MainActor explicitly.
final class CameraService: NSObject, ObservableObject {

    enum Mode: Sendable { case barcode, photo }
    enum Permission: Sendable { case notDetermined, authorized, denied }

    @MainActor @Published private(set) var permission: Permission = .notDetermined
    @MainActor @Published private(set) var mode: Mode = .barcode
    @MainActor @Published private(set) var isRunning: Bool = false
    @MainActor @Published private(set) var lastDetectedBarcode: String? = nil

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session", qos: .userInitiated)

    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<Data, Error>?
    private var configured = false

    private let supportedBarcodeTypes: [AVMetadataObject.ObjectType] = [
        .ean13, .ean8, .upce, .code128, .code39, .code93, .qr, .pdf417
    ]

    override init() {
        super.init()
    }

    // MARK: - Lifecycle

    @MainActor
    func requestAccessIfNeeded() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permission = granted ? .authorized : .denied
        case .denied, .restricted:
            permission = .denied
        @unknown default:
            permission = .denied
        }
    }

    @MainActor
    func start(mode: Mode) async {
        await requestAccessIfNeeded()
        guard permission == .authorized else { return }
        self.mode = mode
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning {
                self.session.startRunning()
                Task { @MainActor in self.isRunning = true }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                Task { @MainActor in self.isRunning = false }
            }
        }
    }

    @MainActor
    func switchMode(to newMode: Mode) {
        guard newMode != self.mode else { return }
        self.mode = newMode
        self.lastDetectedBarcode = nil
        let types = supportedBarcodeTypes
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.metadataOutput.metadataObjectTypes = (newMode == .barcode) ? types : []
            self.session.commitConfiguration()
        }
    }

    @MainActor
    func clearLastBarcode() { lastDetectedBarcode = nil }

    // MARK: - Configuration (session queue only)

    private func configureIfNeeded() {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        guard !configured else { return }
        configured = true

        session.beginConfiguration()
        session.sessionPreset = .photo

        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        guard let device,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            let supported = Set(metadataOutput.availableMetadataObjectTypes)
            let enabled = supportedBarcodeTypes.filter { supported.contains($0) }
            metadataOutput.metadataObjectTypes = enabled
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.unlockForConfiguration()
        } catch {
            // non-fatal
        }

        session.commitConfiguration()
    }

    // MARK: - Still capture

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            self.photoContinuation = continuation
            let settings: AVCapturePhotoSettings
            if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }
            let output = self.photoOutput
            let delegate: AVCapturePhotoCaptureDelegate = self
            sessionQueue.async {
                output.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }
}

// MARK: - Barcode callback

extension CameraService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let readable = metadataObjects
            .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
            .first,
              let value = readable.stringValue, !value.isEmpty else { return }
        Task { @MainActor in
            guard self.mode == .barcode else { return }
            if self.lastDetectedBarcode != value {
                self.lastDetectedBarcode = value
            }
        }
    }
}

// MARK: - Photo callback

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let continuation = self.photoContinuation
        self.photoContinuation = nil
        if let continuation {
            if let error = error { continuation.resume(throwing: error); return }
            if let data = photo.fileDataRepresentation() { continuation.resume(returning: data); return }
            continuation.resume(throwing: NSError(domain: "Camera", code: -1))
        }
    }
}
