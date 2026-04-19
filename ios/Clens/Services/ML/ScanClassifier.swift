import Foundation
@preconcurrency import Vision
import CoreML
@preconcurrency import CoreVideo
import ImageIO

// On-device Core ML binary classifier: "receipt" vs "other".
// Wraps the CreateML-exported ReceiptClassifier.mlmodel behind a simple
// async API so the camera frame pump can ask "is this a receipt?" without
// caring about Vision's request plumbing. Safe to call at ~6 fps.
//
// Initializer is failable. If the model isn't in the bundle (e.g. it hasn't
// been trained yet), AutoRouteController treats classification as unavailable
// and only auto-routes on barcodes. The rest of the app keeps working.
final class ScanClassifier {
    enum Label: String {
        case receipt
        case other
    }

    struct Prediction {
        let label: Label
        let confidence: Float
    }

    private let request: VNCoreMLRequest
    private let queue = DispatchQueue(label: "ml.classifier", qos: .userInitiated)

    init?() {
        let compiledURL = Bundle.main.url(forResource: "ReceiptClassifier", withExtension: "mlmodelc")
        guard let compiledURL else { return nil }
        guard let model = try? MLModel(contentsOf: compiledURL),
              let vnModel = try? VNCoreMLModel(for: model) else {
            return nil
        }
        let req = VNCoreMLRequest(model: vnModel)
        req.imageCropAndScaleOption = .centerCrop
        self.request = req
    }

    func classify(pixelBuffer: CVPixelBuffer,
                  orientation: CGImagePropertyOrientation) async -> Prediction? {
        await withCheckedContinuation { (cont: CheckedContinuation<Prediction?, Never>) in
            queue.async { [request] in
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                    orientation: orientation,
                                                    options: [:])
                do {
                    try handler.perform([request])
                    guard let top = (request.results as? [VNClassificationObservation])?.first,
                          let label = Label(rawValue: top.identifier) else {
                        cont.resume(returning: nil); return
                    }
                    cont.resume(returning: Prediction(label: label, confidence: top.confidence))
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
