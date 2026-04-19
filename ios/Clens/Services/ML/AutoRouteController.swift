import Foundation
import SwiftUI
@preconcurrency import CoreVideo
import ImageIO

// Drives automatic routing between Item (barcode) and Receipt modes while
// the Scan screen is live. Two input streams drive it:
//   1. AVCaptureMetadataOutput fires whenever a barcode is on screen
//      (CameraService now keeps barcode detection on in both camera modes
//      so we can notice "the user pivoted to a product").
//   2. FrameSampler delivers ~6 fps of CVPixelBuffers; ScanClassifier runs
//      the on-device ML model on each to answer "is this a receipt?".
//
// To keep the UI from flickering between modes the controller uses a small
// hysteresis state machine: require a short streak of matching evidence
// before committing, plus a cooldown after every switch. Any manual tab
// tap in ScanView calls disableForManualOverride() — the user's choice is
// authoritative until they re-enable auto-routing.
@MainActor
final class AutoRouteController: ObservableObject, FrameSamplerDelegate {
    enum Detection: Equatable {
        case idle
        case barcode
        case receipt
    }

    @Published private(set) var detection: Detection = .idle
    @Published var enabled: Bool = true

    // Tuning constants. Hardcoded on purpose — tune once during rehearsal
    // and commit, not a settings screen.
    private let receiptConfThreshold: Float = 0.75
    private let framesToCommitReceipt: Int = 5     // ~0.8 s at 6 fps
    private let framesToCommitBarcode: Int = 2     // ~0.3 s
    private let barcodeRecencyWindow: TimeInterval = 0.5
    private let cooldownAfterSwitch: TimeInterval = 2.0

    private var receiptStreak = 0
    private var barcodeStreak = 0
    private var otherStreak = 0
    private var lastSwitchAt: Date = .distantPast
    private var lastCommittedMode: ScanMode?

    private let classifier: ScanClassifier?
    private weak var router: AppRouter?
    private weak var camera: CameraService?

    init() {
        self.classifier = ScanClassifier()
    }

    func bind(router: AppRouter, camera: CameraService) {
        self.router = router
        self.camera = camera
        self.lastCommittedMode = router.scanMode
    }

    func disableForManualOverride() {
        enabled = false
        detection = .idle
        receiptStreak = 0
        barcodeStreak = 0
        otherStreak = 0
    }

    func reenable() {
        enabled = true
        lastSwitchAt = .distantPast
    }

    // MARK: - FrameSamplerDelegate

    nonisolated func frameSampler(_ sampler: FrameSampler,
                                  didSample pixelBuffer: CVPixelBuffer,
                                  orientation: CGImagePropertyOrientation) {
        Task { [weak self] in
            guard let self else { return }
            let enabled = await self.enabled
            guard enabled else { return }

            // Barcode signal: CameraService timestamps the last detection.
            let barcodeRecent = await self.barcodeRecent()

            // Receipt signal: classify this frame (nil if model not loaded).
            let pred = await self.classifier?.classify(pixelBuffer: pixelBuffer,
                                                       orientation: orientation)

            await self.ingest(barcodeVisible: barcodeRecent, receiptPred: pred)
        }
    }

    // MARK: - Internal logic (visible for testing)

    /// Ingests one tick of evidence. Updates detection + commits a mode
    /// switch if the hysteresis thresholds are met. Returns the committed
    /// ScanMode, or nil if nothing changed.
    @discardableResult
    func ingest(barcodeVisible: Bool, receiptPred: ScanClassifier.Prediction?) -> ScanMode? {
        guard enabled else { return nil }
        if Date().timeIntervalSince(lastSwitchAt) < cooldownAfterSwitch {
            return nil
        }

        // Barcodes trump the classifier — AVFoundation's metadata output
        // is already near-perfect precision, so a short streak is safe.
        if barcodeVisible {
            barcodeStreak += 1
            receiptStreak = 0
            otherStreak = 0
            if barcodeStreak >= framesToCommitBarcode {
                return commit(.product)
            }
            return nil
        }
        barcodeStreak = 0

        if let pred = receiptPred,
           pred.label == .receipt,
           pred.confidence >= receiptConfThreshold {
            receiptStreak += 1
            otherStreak = 0
            if receiptStreak >= framesToCommitReceipt {
                return commit(.receipt)
            }
            return nil
        }

        otherStreak += 1
        if otherStreak >= framesToCommitReceipt {
            receiptStreak = 0
        }
        return nil
    }

    private func commit(_ mode: ScanMode) -> ScanMode? {
        guard lastCommittedMode != mode else { return nil }
        lastCommittedMode = mode
        lastSwitchAt = Date()
        detection = (mode == .product) ? .barcode : .receipt
        receiptStreak = 0
        barcodeStreak = 0
        otherStreak = 0
        router?.scanMode = mode
        return mode
    }

    private func barcodeRecent() -> Bool {
        guard let ts = camera?.lastBarcodeObservedAt else { return false }
        return Date().timeIntervalSince(ts) < barcodeRecencyWindow
    }
}
