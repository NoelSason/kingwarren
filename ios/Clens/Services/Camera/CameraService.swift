import Foundation
@preconcurrency import AVFoundation

// Camera session used by ScanView. Manages permission, live barcode
// detection via AVCaptureMetadataOutput, still-image capture via
// AVCapturePhotoOutput, and torch control.
final class CameraService: NSObject, ObservableObject, @unchecked Sendable {

    enum Mode: Sendable { case barcode, photo }
    enum Permission: Sendable { case notDetermined, authorized, denied }

    @MainActor @Published private(set) var permission: Permission = .notDetermined
    @MainActor @Published private(set) var mode: Mode = .barcode
    @MainActor @Published private(set) var isRunning: Bool = false
    @MainActor @Published private(set) var lastDetectedBarcode: String? = nil
    @MainActor @Published private(set) var torchOn: Bool = false
    @MainActor @Published private(set) var torchSupported: Bool = false
    @MainActor @Published private(set) var unavailable: Bool = false
    // Timestamp of the most recent barcode sighting, regardless of the
    // current camera mode. AutoRouteController samples this to detect
    // "user swung the phone onto a product" even while we're still in
    // .photo (receipt) mode.
    @MainActor @Published private(set) var lastBarcodeObservedAt: Date? = nil

    let session = AVCaptureSession()
    // Exposed so ScanView can wire the auto-router as the frame delegate.
    let frameSampler = FrameSampler()
    private let sessionQueue = DispatchQueue(label: "camera.session", qos: .userInitiated)

    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<Data, Error>?
    private var configured = false
    private var configurationFailed = false
    private var device: AVCaptureDevice?

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
        // Guard against duplicate starts firing startRunning twice from
        // overlapping .task invocations.
        guard !isRunning, !unavailable else { return }
        self.mode = mode
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            // If config failed (no device, simulator, preset refused),
            // don't call startRunning — that's what produces the repeated
            // FigCaptureSourceRemote err=-17281 asserts.
            guard !self.configurationFailed,
                  !self.session.inputs.isEmpty else {
                Task { @MainActor in self.unavailable = true }
                return
            }
            self.applyMode(mode)
            if !self.session.isRunning {
                self.session.startRunning()
                let running = self.session.isRunning
                let hasTorch = self.device?.hasTorch ?? false
                Task { @MainActor in
                    self.isRunning = running
                    self.torchSupported = hasTorch
                }
            }
        }
    }

    // Stop synchronously on the session queue so the caller (onDisappear)
    // doesn't return while AVFoundation is still tearing down — that race
    // is what produces the FigXPC / FigCaptureSourceRemote asserts and
    // leaves the UI stuck after dismissal.
    func stop() {
        sessionQueue.sync { [weak self] in
            guard let self else { return }
            // Cancel any in-flight photo continuation so we don't leak it.
            if let cont = self.photoContinuation {
                self.photoContinuation = nil
                cont.resume(throwing: CancellationError())
            }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            // Kill torch on dismiss.
            if let d = self.device, d.hasTorch, d.isTorchActive {
                try? d.lockForConfiguration()
                d.torchMode = .off
                d.unlockForConfiguration()
            }
        }
        Task { @MainActor in
            self.isRunning = false
            self.torchOn = false
        }
    }

    @MainActor
    func switchMode(to newMode: Mode) {
        guard newMode != self.mode else { return }
        self.mode = newMode
        self.lastDetectedBarcode = nil
        sessionQueue.async { [weak self] in
            self?.applyMode(newMode)
        }
    }

    @MainActor
    func clearLastBarcode() { lastDetectedBarcode = nil }

    @MainActor
    func toggleTorch() {
        let desiredOn = !torchOn
        sessionQueue.async { [weak self] in
            guard let self, let d = self.device, d.hasTorch else { return }
            do {
                try d.lockForConfiguration()
                d.torchMode = desiredOn ? .on : .off
                d.unlockForConfiguration()
                Task { @MainActor in self.torchOn = desiredOn }
            } catch {
                // ignore
            }
        }
    }

    // MARK: - Configuration (session queue only)

    private func applyMode(_ m: Mode) {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        session.beginConfiguration()
        // Barcode metadata stays enabled in both camera modes so the
        // AutoRouteController can notice a product pivot while the camera
        // is in .photo mode. The delegate callback still gates navigation
        // on the current mode (see metadataOutput(_:didOutput:from:) below).
        let supported = Set(metadataOutput.availableMetadataObjectTypes)
        metadataOutput.metadataObjectTypes = supportedBarcodeTypes.filter { supported.contains($0) }
        _ = m
        session.commitConfiguration()
    }

    private func configureIfNeeded() {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        guard !configured else { return }
        configured = true

        // Simulator has no camera hardware — bail early instead of letting
        // AVFoundation spam FigCaptureSourceRemote asserts.
        #if targetEnvironment(simulator)
        configurationFailed = true
        return
        #else
        session.beginConfiguration()
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        } else {
            session.sessionPreset = .high
        }

        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        guard let device,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            configurationFailed = true
            return
        }
        self.device = device
        session.addInput(input)

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        frameSampler.attach(to: session)

        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.unlockForConfiguration()
        } catch {
            // non-fatal
        }

        session.commitConfiguration()
        #endif
    }

    // MARK: - Still capture

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                // Guard against a double-capture leak if stop() just cleared one.
                if self.photoContinuation != nil {
                    continuation.resume(throwing: NSError(domain: "Camera", code: -2))
                    return
                }
                self.photoContinuation = continuation
                let settings: AVCapturePhotoSettings
                if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                } else {
                    settings = AVCapturePhotoSettings()
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
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
        let symbology = readable.type.rawValue
        Task { @MainActor in
            // Always update the observation timestamp — the auto-router
            // uses it to decide "barcode in frame right now" regardless
            // of the current camera mode.
            self.lastBarcodeObservedAt = Date()
            // Only publish the decoded string for navigation when the
            // user is actually in product mode; otherwise the receipt
            // flow would get hijacked by an ambient barcode.
            guard self.mode == .barcode else { return }
            if self.lastDetectedBarcode != value {
                ScanLog.step(1, "camera decoded barcode: '\(value)' symbology=\(symbology)")
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
        guard let continuation else { return }
        if let error = error { continuation.resume(throwing: error); return }
        if let data = photo.fileDataRepresentation() { continuation.resume(returning: data); return }
        continuation.resume(throwing: NSError(domain: "Camera", code: -1))
    }
}
