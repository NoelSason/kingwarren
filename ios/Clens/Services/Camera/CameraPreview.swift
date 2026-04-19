import SwiftUI
import AVFoundation

// SwiftUI wrapper around AVCaptureVideoPreviewLayer so ScanView can show
// a live camera feed behind the reticle overlay.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if #available(iOS 17, *) {
            view.previewLayer.connection?.videoRotationAngle = 90
        } else {
            view.previewLayer.connection?.videoOrientation = .portrait
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
