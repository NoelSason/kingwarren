#!/usr/bin/env swift
// Trains the on-device receipt/other classifier that AutoRouteController
// loads inside the iOS app. Uses Apple's CreateML framework so there's
// no Python / PyTorch dependency chain to wrangle the night before the
// hackathon deadline.
//
// Inputs:
//   - Receipts:  Receipt ML/large-receipt-image-dataset-SRD (1)/*.jpg
//                (~200 images, already on disk)
//   - Negatives: ml/negatives/*.{jpg,png,jpeg}
//                (you supply ~200 non-receipt images — hands, produce,
//                 product packaging, random scenes. Mix public datasets
//                 with team self-captures.)
//
// Output:
//   - ios/Clens/Resources/ML/ReceiptClassifier.mlmodel
//     Xcode auto-compiles this to ReceiptClassifier.mlmodelc at build
//     time; ScanClassifier.swift loads the compiled form from the bundle.
//
// Run from the repo root:
//   swift ml/train_receipt_classifier.swift
//
// Requires macOS 13+ with Xcode command-line tools. ~20 minutes end-to-end.

import Foundation
import CreateML
import CoreML

// MARK: - Paths (relative to repo root / cwd)

let fm = FileManager.default
let cwd = URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)

let receiptsSource = cwd.appendingPathComponent("Receipt ML/large-receipt-image-dataset-SRD (1)",
                                                isDirectory: true)
let negativesSource = cwd.appendingPathComponent("ml/negatives", isDirectory: true)
let stagingRoot = cwd.appendingPathComponent("ml/dataset", isDirectory: true)
let outputModel = cwd.appendingPathComponent("ios/Clens/Resources/ML/ReceiptClassifier.mlmodel")

let trainRoot = stagingRoot.appendingPathComponent("train", isDirectory: true)
let validationRoot = stagingRoot.appendingPathComponent("validation", isDirectory: true)

// MARK: - Helpers

func log(_ msg: String) {
    FileHandle.standardError.write(Data("[train] \(msg)\n".utf8))
}

func listImages(in folder: URL) -> [URL] {
    guard let items = try? fm.contentsOfDirectory(at: folder,
                                                  includingPropertiesForKeys: nil,
                                                  options: [.skipsHiddenFiles]) else {
        return []
    }
    let exts: Set<String> = ["jpg", "jpeg", "png"]
    return items.filter { exts.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

func recreate(_ folder: URL) throws {
    if fm.fileExists(atPath: folder.path) {
        try fm.removeItem(at: folder)
    }
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
}

/// Copies up to `trainCount` files to train/<class>/, next `valCount` to
/// validation/<class>/. Uses deterministic ordering (sorted by filename)
/// so reruns are reproducible.
func stage(_ images: [URL], className: String, trainCount: Int, valCount: Int) throws {
    let trainDir = trainRoot.appendingPathComponent(className, isDirectory: true)
    let valDir = validationRoot.appendingPathComponent(className, isDirectory: true)
    try fm.createDirectory(at: trainDir, withIntermediateDirectories: true)
    try fm.createDirectory(at: valDir, withIntermediateDirectories: true)

    let take = min(images.count, trainCount + valCount)
    for (idx, src) in images.prefix(take).enumerated() {
        let dest = (idx < trainCount ? trainDir : valDir)
            .appendingPathComponent(src.lastPathComponent)
        try? fm.removeItem(at: dest)
        try fm.copyItem(at: src, to: dest)
    }
    log("staged \(take) \(className) images (train: \(min(take, trainCount)), val: \(max(0, take - trainCount)))")
}

// MARK: - Build staging folders

let receipts = listImages(in: receiptsSource)
guard !receipts.isEmpty else {
    log("ERROR: no receipts at \(receiptsSource.path)")
    exit(1)
}

let negatives = listImages(in: negativesSource)
guard !negatives.isEmpty else {
    log("ERROR: no negatives at \(negativesSource.path).")
    log("       Populate ml/negatives/ with ~150-200 non-receipt images")
    log("       (hands, produce, packaging, random scenes) and rerun.")
    exit(1)
}

log("found \(receipts.count) receipts, \(negatives.count) negatives")

try recreate(stagingRoot)
try fm.createDirectory(at: trainRoot, withIntermediateDirectories: true)
try fm.createDirectory(at: validationRoot, withIntermediateDirectories: true)

let receiptTrain = Int(Double(receipts.count) * 0.8)
let receiptVal = receipts.count - receiptTrain
let negTrain = Int(Double(negatives.count) * 0.8)
let negVal = negatives.count - negTrain

try stage(receipts, className: "receipt", trainCount: receiptTrain, valCount: receiptVal)
try stage(negatives, className: "other", trainCount: negTrain, valCount: negVal)

// MARK: - Train

log("training MLImageClassifier (transfer learning, Image Feature Print)…")
let trainingSource = MLImageClassifier.DataSource.labeledDirectories(at: trainRoot)
let validationSource = MLImageClassifier.DataSource.labeledDirectories(at: validationRoot)

let params = MLImageClassifier.ModelParameters(
    validation: .dataSource(validationSource),
    maxIterations: 25,
    augmentation: [.crop, .rotation, .blur, .noise, .exposure],
    algorithm: .transferLearning(
        featureExtractor: .scenePrint(revision: 2),
        classifier: .logisticRegressor
    )
)

let classifier = try MLImageClassifier(trainingData: trainingSource, parameters: params)

log("training metrics:")
log("  training accuracy   = \(1.0 - classifier.trainingMetrics.classificationError)")
log("  validation accuracy = \(1.0 - classifier.validationMetrics.classificationError)")

// MARK: - Export

let metadata = MLModelMetadata(
    author: "CLENS team",
    shortDescription: "Binary classifier: live camera frame is a grocery receipt or not.",
    version: "1.0"
)

try fm.createDirectory(at: outputModel.deletingLastPathComponent(),
                       withIntermediateDirectories: true)
try classifier.write(to: outputModel, metadata: metadata)
log("wrote \(outputModel.path)")
log("done. Rerun `xcodegen generate` in ios/ so Xcode picks the model up.")
