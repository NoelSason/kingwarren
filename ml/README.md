# Receipt Classifier Training

Trains the `ReceiptClassifier.mlmodel` that the iOS app uses for live auto-routing between barcode and receipt scan modes. Binary classifier: `receipt` vs. `other`.

## One-time setup

### 1. Populate `ml/negatives/` with ~150–200 non-receipt images

The positive (`receipt`) class is already on disk at `Receipt ML/large-receipt-image-dataset-SRD (1)/` — ExpressExpense SRD, 200 images.

The negative (`other`) class is up to you to supply. Drop JPG/PNG files into `ml/negatives/`. Aim for a mix:

- **Adversarial negatives (most important)** — photograph product packaging, cereal boxes, grocery items held at scan distance. These look paper-like and will trip up a naïve classifier. Target ~50 images.
- **Scene negatives** — hands on tables, random indoor shots, produce, phones, faces. Any random natural image works. Target ~100 images.
- **Public dataset subsets** — COCO val2017, Open Images, ImageNet. Sample ~50 random images for volume.

Rule of thumb: if you'd expect the camera to see it during normal phone use *and it isn't a receipt*, it belongs in `other`.

### 2. Run training

From the repo root:

```
swift ml/train_receipt_classifier.swift
```

Requires macOS 13+ with Xcode command-line tools. ~10–20 minutes on M-series. Outputs:

- `ml/dataset/` — staged train/validation splits (regenerated on every run; safe to delete)
- `ios/Clens/Resources/ML/ReceiptClassifier.mlmodel` — the trained model

### 3. Regenerate the Xcode project

The new model file needs to be added to the Xcode target:

```
cd ios && xcodegen generate
```

Build & run on a physical device (simulator has no camera). The `AutoRouteController` detects the model at startup; if it isn't in the bundle, auto-routing silently falls back to barcode-only and the manual tabs still work.

## Tuning

If the classifier is too eager or too sluggish on-device, tune these in `ios/Clens/Services/ML/AutoRouteController.swift`:

- `receiptConfThreshold: Float = 0.75` — raise if too many false positives
- `framesToCommitReceipt: Int = 5` — raise if the mode flickers

## Expected accuracy

With 160 train + 40 validation per class, expect >95% validation accuracy. The live demo is what matters, though — rehearse with the *specific* receipt you'll show to judges.
