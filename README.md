# CLENS

An iPhone app that turns grocery shopping into an ocean-health feedback loop. Scan a receipt or a product, get an **OceanScore** from 0–100, earn **sea bucks**, and see better swaps — all adjusted in real time by an ML-derived stress index of the Southern California coastal ocean.

Built for **DataHacks 2026** (Scripps Challenge track).

---

## How we built this project

CLENS is a pipeline, not a monolith. Four independent seams glue together:

```
  camera frame ─► on-device CoreML classifier ─► route (barcode vs receipt)
                                                  │
                 ┌────────────────────────────────┼──────────────────────────┐
                 ▼                                ▼                          ▼
        Vision OCR (receipt)            AVFoundation barcode          Label vision (Claude)
                 │                                │                          │
                 └──────────► normalized FoodItem ◄──────────────────────────┘
                                         │
                                         ▼
                         EnvRegressionModel  (category+size → CO₂, runoff, plastic, water)
                                         │
                                         ▼
                         OceanScoreEngine × stress index from CCE2 mooring ML
                                         │
                                         ▼
                         0–100 score  +  sea bucks  +  swap suggestions
                                         │
                                         ▼
                         Supabase (profile, rewards, leaderboard)
```

### The process, in order

1. **Locked the API contract first.** Before any model code, we fixed the shape `(camera input) → FoodItem → Scored`. That let Aarav (scanning), Shaun (ML), Warren (product/design), and Noel (frontend) work in parallel without merge chaos. `ios/Clens/Services/Scoring/FoodItem.swift` is the contract.
2. **Built the app shell + mocks.** `RootView`, `AppRouter`, `TabBarView`, and every screen in `ios/Clens/Screens/` were stood up with `MockData.swift` driving them, so the demo flow was clickable end-to-end before any real scoring worked.
3. **Stood up the ocean-stress ML notebook** (`project_oceanscore (4).py`). Pulled CCE2 mooring data live from NDBC THREDDS, decomposed seasonality with STL, and fit an Isolation Forest on the residuals to produce a single scalar stress index in [0, 2].
4. **Trained the on-device receipt classifier** (`ml/train_receipt_classifier.swift`). Binary CoreML model — "receipt" vs "other" — so the camera can auto-route the UI without the user tapping a tab. Uses the ExpressExpense SRD (200 receipts) as positives and ~200 hand-curated negatives.
5. **Fit the environmental regression** (`ml/env_regression/train.py`). A pure-stdlib ridge regression predicting `(co2_kg, runoff_intensity, plastic_intensity, water_l_per_kg)` from `(category one-hot, log size_kg)`. Trained on a curated Agribalyse subset. Output is codegen'd directly into Swift at `ios/Clens/Services/Scoring/EnvRegressionModel.swift` so there's no runtime dependency or download.
6. **Wrote the scoring engine.** `OceanScoreEngine.swift` blends the regression with OpenFoodFacts per-SKU data (Agribalyse CO₂, packagings[], LLM-estimated water), applies a softened stress multiplier, and produces both a composite 0–100 score and four per-factor "goodness" bars for the UI.
7. **Plumbed the backend.** Flask + Supabase (`backend/app.py`, `backend/db.py`, `backend/supabase_schema.sql`) for profile sync, rewards, and the leaderboard. Ocean stress is exposed at `GET /api/ocean-stress`.
8. **Rehearsed the demo loop.** Receipt scan → line items → per-item scores → basket total → sea bucks → swap suggestions — on a physical device, because the simulator has no camera.

### Repo layout

```
ios/Clens/                    SwiftUI app (iOS 17+)
  Screens/                    Home, Scan, ReceiptResult, Rewards, Leaderboard, Profile, …
  Services/
    Camera/                   AVFoundation capture + frame sampler
    ML/                       ScanClassifier (CoreML) + AutoRouteController hysteresis
    OCR/                      Apple Vision VNRecognizeTextRequest receipt parser
    Network/                  Supabase, OpenFoodFacts, Claude label vision, profile sync
    Ocean/                    OceanStressService (reads stress index)
    Scoring/                  OceanScoreEngine, EnvRegressionModel, CategoryImpacts, FoodItem
  Resources/ML/               Bundled: ReceiptClassifier.mlmodel + env_regression.json

ml/
  train_receipt_classifier.swift   CreateML trainer for the binary receipt model
  env_regression/train.py          Trains the per-SKU impact regression → codegen'd to Swift
  negatives/                       Hand-curated negatives for receipt classifier

Receipt ML/large-receipt-image-dataset-SRD (1)/   ExpressExpense SRD positives

backend/
  app.py                      Flask API: profile, ocean stress endpoint
  db.py                       Supabase + Databricks wrapper
  supabase_schema.sql         Schema for profiles, scans, rewards, leaderboard

project_oceanscore (4).py     Shaun's Colab notebook: CCE2 → STL → Isolation Forest → stress index
model_evaluation.pdf          Held-out RMSE/MAE + synthetic anomaly P/R/F1 for the stress model
docs/                         Planning docs + hackathon requirements
```

---

## How to run this project

### Prerequisites

- macOS 13+ with Xcode 15+ (for the iOS app and CoreML training)
- Python 3.10+ (for the backend and stress-index notebook)
- An iPhone — the simulator has no camera, and the whole app is camera-driven
- API keys: `ANTHROPIC_API_KEY` (label vision), `SUPABASE_URL` + `SUPABASE_ANON_KEY` (profile/rewards), optional `API_BASE_URL` (Flask backend)

### 1. iOS app

```bash
# Secrets (one-time) — fill in ios/Clens/Secrets.xcconfig:
#   ANTHROPIC_API_KEY = sk-ant-...
#   SUPABASE_URL = https://xxx.supabase.co
#   SUPABASE_ANON_KEY = ey...
#   API_BASE_URL = http://<your-mac-ip>:5000

# Generate the Xcode project from project.yml
cd ios
brew install xcodegen   # once
xcodegen generate

# Open and run on a physical device
open Clens.xcodeproj
```

If `ReceiptClassifier.mlmodel` isn't in `ios/Clens/Resources/ML/`, `AutoRouteController` silently falls back to barcode-only mode and the manual Item/Receipt tabs still work — the rest of the app doesn't break.

### 2. Train the receipt classifier (optional, ~15 min)

```bash
# Drop ~150–200 non-receipt images into ml/negatives/ (see ml/README.md for the mix)
swift ml/train_receipt_classifier.swift
# Writes ios/Clens/Resources/ML/ReceiptClassifier.mlmodel
cd ios && xcodegen generate
```

### 3. Regenerate the environmental regression

```bash
# Pure stdlib — no numpy needed
python3 ml/env_regression/train.py
# Writes ml/env_regression/model.json, ios/Clens/Resources/ML/env_regression.json,
# and regenerates the Swift coefficients at
# ios/Clens/Services/Scoring/EnvRegressionModel.swift
```

### 4. Backend (Flask + Supabase)

```bash
pip install -r requirements.txt
export SUPABASE_URL=...
export SUPABASE_KEY=...
export FLASK_SECRET_KEY=dev
python backend/app.py          # http://localhost:5000
```

Endpoints:
- `GET  /api/health`             — reports which backends are configured
- `POST /api/profile`            — upsert profile on sign-up
- `GET  /api/profile/<user_id>`  — fetch profile
- `GET  /api/ocean-stress`       — current stress index (served statically today; swap to Shaun's live pipeline output when deployed)

### 5. Ocean-stress ML pipeline

Open `project_oceanscore (4).py` as a Colab notebook (or run the cells locally with `xarray`, `netCDF4`, `pydap`, `statsmodels`, `scikit-learn`). It pulls CCE2 deployment 17 over OPeNDAP, fits the model, and prints the current stress index. Paste that value into `/api/ocean-stress` (or wire it into a job that re-writes the endpoint daily).

---

## How ML is integrated with environment scores and receipt checking

There are **three separate ML components**, each solving a different problem. The trick is that they feed each other:

### ML #1 — Receipt vs. product classifier (on-device CoreML)

**Job:** decide, in real time, whether the camera is looking at a receipt or a product, so the scan UI routes itself.

- **Training:** `ml/train_receipt_classifier.swift` uses CreateML's `MLImageClassifier` on the ExpressExpense SRD dataset (200 receipts) plus ~200 hand-curated adversarial negatives (product packaging, hands on tables, cereal boxes — things that look paper-like).
- **Runtime:** `ScanClassifier.swift` loads the `.mlmodelc`, wraps it in a `VNCoreMLRequest`, and `AutoRouteController.swift` samples frames at ~6 fps. A hysteresis state machine (5-frame receipt streak, 2-frame barcode streak, 2 s cooldown after every switch) prevents flicker. Barcode metadata detections trump the classifier — AVFoundation's precision is near-perfect, so a short streak is safe.
- **Why it matters:** the user never taps a mode. They point the phone and the app flips between "scan this product" and "scan this receipt" automatically.

### ML #2 — Per-SKU impact regression (codegen'd to Swift)

**Job:** given a food category and pack size, predict its four environmental intensities.

- **Training:** `ml/env_regression/train.py`. Pure stdlib Gaussian elimination with a tiny ridge term (λ = 1e-6) — we chose this over sklearn so anyone on the team can regenerate the model without a data-science env. Features are `[bias, 12-way category one-hot, log(size_kg)]`. Targets: `co2_kg`, `runoff_intensity`, `plastic_intensity`, `water_l_per_kg`. Trained on a curated Agribalyse subset at `ml/env_regression/agribalyse_curated.csv`. Reports per-target R² and MAE.
- **Deployment:** the trainer **writes Swift source code** (`EnvRegressionModel.swift`) containing the learned coefficients as literal arrays. No runtime JSON parsing, no model file to bundle, no version skew — the regression *is* the compiled app. It also drops a JSON copy into the bundle for inspection.
- **Integration:** `OceanScoreEngine.modelBlendedFactors(...)` calls `EnvRegressionModel.predict(category:, sizeKg:)` for every scanned item.

### ML #3 — Ocean stress index (CCE2 mooring, Scripps)

**Job:** produce a single scalar in [0, 2] representing how stressed the Southern California coastal ocean is *right now*, so runoff-heavy items get penalized more during bad weeks.

- **Data:** `project_oceanscore (4).py` pulls live `CCE2` mooring data (deployment 17) straight from NDBC THREDDS via OPeNDAP — pH, dissolved oxygen, chlorophyll, nitrate. Hourly resampled, gaps < 6 h interpolated.
- **Model:** STL seasonal decomposition (weekly period) strips the Southern California upwelling cycle so we detect "unusual for this time of year," not normal seasonality. Residuals go through `RobustScaler`, then an `IsolationForest` (contamination=0.1, fit on the first 70% of the record). Anomaly scores are flipped and rescaled against the 5th/95th percentiles of the train split, producing the 0–2 index.
- **Evaluation** (see `model_evaluation.pdf`):
  - Forecast RMSE/MAE of the STL trend+seasonal component as a persistence baseline
  - Synthetic anomaly injection on the test set → precision / recall / F1
  - Historical event recovery for the 2014–2016 Northeast Pacific warm anomaly on CCE2 deployments 9–11
  - Spearman rank correlation against a small hand-labeled product set
- **Delivery:** Shaun's notebook writes the latest scalar to `/api/ocean-stress`. The iOS app's `OceanStressService` reads it at launch and keeps it in an `@Published` property; today the demo uses a mock value (1.34×) so the UI stays deterministic during judging.

### How it all correlates with food items

The three ML systems meet inside `OceanScoreEngine.modelBlendedFactors(for:stressIndex:)`:

```
1. AutoRouteController classifies the frame → "receipt" vs "product"

2a. Product path:
    AVFoundation barcode → OpenFoodFactsClient → FoodItem with
    agribalyseCO2Kg, plasticScore (from packagings[]), keyIngredients
    ── OR ──
    Label vision (Claude) fills in category / organic / local /
    packaging / key ingredients when OFF has no record

2b. Receipt path:
    Apple Vision OCR → ReceiptOCRService.parse() extracts line items
    with a price regex, classifies "GRND BF 80/20" → .beef via
    categoryTokens, detects "ORG " prefix as the organic signal

3. EnvRegressionModel.predict(category:, sizeKg:) gives a baseline
   (co2Kg, runoffI, plasticI, waterL). When OFF has real data:
     - agribalyseCO2Kg OVERRIDES the regression's co2 prediction
     - plasticScore from packagings[] OVERRIDES plastic intensity
       (critical: it knows a Monster can is aluminum, not PET)
     - cans/glass clamp plastic intensity to ≤ 0.15 as a guardrail

4. Size scaling: climate and water are per-kg, so a 1 kg jug gets
   √(1.0/0.5) ≈ 1.4× the impact of a 500 g item. Runoff stays
   per-kg (farming attribute, size-independent).

5. Stress: the CCE2 index is clamped to [0.8, 1.2] (softenStress)
   so a spike can't zero out every factor. We then compute each
   factor twice — once at stress=1.0, once at the clamped live
   stress — and blend 50/50. Stress influences the score without
   dominating it.

6. Factor curves:
   - climate/water → sqrt-compressed goodness (pulls typical items
     off the "everything green" ceiling)
   - runoff/plastic → smootherstep S-curve (6t⁵-15t⁴+10t³, more
     discrimination in the middle, tight at edges)

7. Composite: 0.30·co2 + 0.30·runoff + 0.25·plastic + 0.15·water
   → 0–100 score → CLAUDE.md tier points (10/6/3/1) → sea bucks
```

The practical outcome: during a bad week (stress 1.34×), a conventional ground beef scan loses more points to runoff than it would in a calm week, while a can of beans barely moves — because the S-curve for runoff is steep in the middle and shallow at the edges. That's the connection the pitch makes real: *real ocean data, measured at Scripps, is changing the score on your phone right now.*

---

## Demo story

1. Scan a receipt (`ScanView` → auto-routes to receipt mode via ML #1)
2. OCR pulls line items (`ReceiptOCRService`)
3. Each item is categorized and scored (`OceanScoreEngine` using ML #2 + ML #3)
4. `ReceiptResultView` shows per-item scores, the basket total, and sea bucks
5. Runoff penalty is visibly larger this week — caption reads *"score adjusted for current Southern California ocean stress conditions"* (ML #3)
6. Swap suggestions show how many more points the user would have earned
7. Profile / rewards / leaderboard sync to Supabase

## Scoring guardrails (what we don't claim)

- We do **not** claim a dataset identified a specific SKU, or that any receipt causes a specific bloom.
- The stress index is a *regional* signal, used as a multiplier, not a causal attribution.
- Safe phrasing: "runoff-heavy products are penalized more when marine ecosystems are under greater stress."

## Team

- **Aarav** — scanning features
- **Shaun** — ML (ocean stress pipeline, evaluation)
- **Warren** — product / design / frontend
- **Noel** — frontend coding
