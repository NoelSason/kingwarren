import Foundation
@preconcurrency import AVFoundation
import CoreVideo
import ImageIO

// Taps the AVCaptureSession's video output, throttles frames down to a low
// classification-friendly rate (~6 fps), and hands the CVPixelBuffer off to
// a delegate for on-device ML work. alwaysDiscardsLateVideoFrames keeps the
// pipeline from backing up if classification lags.
protocol FrameSamplerDelegate: AnyObject {
    func frameSampler(_ sampler: FrameSampler,
                      didSample pixelBuffer: CVPixelBuffer,
                      orientation: CGImagePropertyOrientation)
}

final class FrameSampler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var delegate: FrameSamplerDelegate?

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.frames", qos: .userInitiated)
    private var lastSampleAt: CFTimeInterval = 0
    private let minInterval: CFTimeInterval = 1.0 / 6.0

    func attach(to session: AVCaptureSession) {
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        if let connection = output.connection(with: .video) {
            if #available(iOS 17, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastSampleAt >= minInterval else { return }
        lastSampleAt = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        delegate?.frameSampler(self, didSample: pixelBuffer, orientation: .right)
    }
}
