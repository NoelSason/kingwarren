# OceanScore Team Plan

Last updated: April 18, 2026  
Project concept: a grocery sustainability rewards app that scans items and receipts, assigns an `Ocean Score`, awards points, suggests higher-scoring alternatives, and reacts to real ocean conditions using a Scripps dataset.

This plan is written for a beginner team that wants to work in parallel with as few merge conflicts as possible.

## 1. Project Summary

### Core app idea

Users scan:

- an individual grocery item while shopping
- a full receipt after shopping
- optionally a recycling/trash-bin photo for bonus points

The app then:

- identifies products from images or OCR text
- classifies them into food/product categories
- scores them using `climate impact`, `runoff impact`, and `plastic impact`
- adjusts scoring based on `real ocean conditions`
- gives points and suggests better alternatives

### User-facing hook

People care about:

- discounts
- rewards
- saving money
- easy swaps
- gamification

The ocean/environment story is the justification behind the score, not the main marketing pitch.

### Scientific hook

The app should use `CalCOFI` as the primary Scripps dataset so the project is eligible for the Scripps challenge.

Important constraint:

- `CalCOFI` is good for ocean condition context.
- `CalCOFI` is not a grocery product database.
- So we should use it as an `ocean stress multiplier`, not as the only source of product scoring.

Recommended framing:

> The app gives each item a baseline impact score, then adjusts the weighting based on current or recent marine ecosystem stress signals from CalCOFI.

## 2. Team Split

### Aarav/Sean

Primary responsibility:

- ML pipeline design
- product classification logic
- score-model rules and confidence thresholds
- scanned item to Ocean Score mapping
- backend scoring integration
- receipt and item scan screens
- OCR pipeline
- receipt text cleaning
- scan API endpoints
- item and receipt scanning robustness
- sample scan datasets and preprocessing


Should mostly own:

- `backend/classification/`
- `backend/scoring/`
- ML evaluation logic and model/output schemas

### Noel/Warren

Primary responsibility:

- app skeleton
- navigation
- camera/upload UI
- frontend integration layer for scan and score results
- results and rewards UI
- alternative recommendations UX
- shared UI components
- product copy, user stories, and presentation language

Should mostly own:

- `frontend/src/screens/Home.tsx`
- `frontend/src/screens/ReceiptScan.tsx`
- `frontend/src/screens/ItemScan.tsx`
- `frontend/src/lib/`




Should mostly own:

- `frontend/src/screens/Results.tsx`
- `frontend/src/screens/Rewards.tsx`
- `frontend/src/components/`
- `docs/product/`




Should mostly own:

- `backend/ocr/`
- `backend/api/scan_*`
- `data/sample_receipts/`
- `data/sample_items/`

### Shared responsibilities

Everyone should help with:

- testing
- demo preparation
- README
- bug fixes on their own area

Primary pairing split:

- Noel and Warren own the app skeleton and frontend experience
- Aarav and Sean own ML, OCR, scanning, and scan-to-score backend flow

Only one person at a time should touch:

- root config files
- README
- deployment config
- package manager lockfiles

That reduces merge conflicts.

## 3. Repo Structure To Create First

Create this structure before heavy coding:

```text
frontend/
  src/
    components/
    screens/
    lib/
backend/
  api/
  ocr/
  classification/
  scoring/
  data_ingest/
data/
  sample_receipts/
  sample_items/
  score_rules/
docs/
  product/
  research/
  judging/
scripts/
```

### Ownership by folder

- Noel owns the frontend app shell in `frontend/src/screens/` for home and scan entry flows plus `frontend/src/lib/`
- Warren owns `frontend/src/components/`, the results/rewards flows, and `docs/product/`
- Sean owns `backend/ocr/`, `backend/api/scan_*`, and sample scan data
- Aarav owns `backend/classification/`, `backend/scoring/`, and ML/scoring evaluation logic
- Shared logic for final integration can live across `frontend/` and `backend/`, but one person should be designated as the editor for each file

## 4. Branch Strategy

You should not all work on `main`.

### Branch naming

Use short, consistent branch names:

- `noel/app-skeleton`
- `warren/results-rewards-ui`
- `aarav/ml-scoring`
- `sean/scan-pipeline`
- later integration branches:
  - `noel/frontend-integration`
  - `warren/demo-ui-polish`
  - `aarav/classifier-scoring`
  - `sean/ocr-api-hardening`

### One-time setup for everyone

Run this after cloning or opening the repo:

```bash
git checkout main
git pull origin main
```

### Create a branch

Example for Noel:

```bash
git checkout main
git pull origin main
git checkout -b noel/app-skeleton
```

Example for Warren:

```bash
git checkout main
git pull origin main
git checkout -b warren/results-rewards-ui
```

Example for Aarav:

```bash
git checkout main
git pull origin main
git checkout -b aarav/ml-scoring
```

Example for Sean:

```bash
git checkout main
git pull origin main
git checkout -b sean/scan-pipeline
```

### Push your branch to GitHub

After the first commit on a branch:

```bash
git push -u origin <branch-name>
```

Example:

```bash
git push -u origin sean/scan-pipeline
```

## 5. Beginner-Safe Git Workflow

Do this every time before you start new work:

```bash
git checkout main
git pull origin main
git checkout <your-branch>
git merge main
```

Then do your work.

When you finish a chunk:

```bash
git add .
git commit -m "clear message here"
git push
```

### Good commit message examples

- `create frontend app skeleton`
- `add receipt OCR preprocessing pipeline`
- `implement classifier to score mapping`
- `connect receipt upload screen to scan API`

### Avoid these commit messages

- `stuff`
- `changes`
- `latest`
- `fix`

Use a message that says what changed.

## 6. How To Avoid Merge Conflicts

### Rule 1: Separate file ownership

Try not to have multiple people editing the same file at the same time.

### Rule 2: Keep root files stable

Do not casually edit these unless your team agrees first:

- `README.md`
- root `package.json`
- `tsconfig.json`
- `.env.example`
- deployment config files

### Rule 3: Use one integration owner at a time

When it is time to wire frontend to backend:

- Noel or Warren edits frontend integration files, but only one of them should own a given file at a time
- Sean exposes stable scan endpoints
- Aarav updates classification and scoring contracts

### Rule 4: Merge small changes often

Do not wait 8 hours to merge a giant branch.

Better:

- commit small pieces
- push often
- merge often

### Rule 5: Announce file ownership in chat

Use a simple message in Discord or group chat:

- `I am editing frontend/src/screens/ReceiptScan.tsx for the next hour`
- `I am touching backend/classification/parser.py now`

That avoids silent collisions.

## 7. Merge Process

When a branch is ready:

```bash
git checkout main
git pull origin main
git checkout <your-branch>
git merge main
```

Fix any merge issues on your branch first.

Then:

```bash
git checkout main
git merge <your-branch>
git push origin main
```

If you use GitHub pull requests, even better. For beginners, PRs are safer because someone else can review before merge.

## 8. Recommended Build Order

Build in this order so each person can work mostly independently.

### Phase 1: Foundation

Goal:

- create repo structure
- choose stack
- define API contracts
- define scoring schema

Deliverables:

- working branch structure
- folder structure
- basic README
- one product spec file

### Phase 2: Independent work

Goal:

- Noel and Warren build the app skeleton
- Sean builds OCR + scanning APIs
- Aarav builds ML classification + scoring logic

Deliverables:

- navigable app shell
- a working OCR prototype on sample receipts
- a classifier/scoring prototype on sample items

### Phase 3: Scoring integration

Goal:

- connect Sean's scan output to Aarav's Ocean Score engine
- connect score engine to CalCOFI-based ocean multiplier
- wire Noel and Warren's UI to the real backend response

Deliverables:

- API returns:
  - parsed receipt items
  - classified categories
  - item-level score
  - total score
  - points earned

### Phase 4: What-if + alternatives

Goal:

- suggest alternatives with higher points
- show potential score improvement

Deliverables:

- `swap this item for that item`
- `you would gain X more points`
- pros/cons explanation

### Phase 5: Polish + demo

Goal:

- improve UI
- hardcode a few realistic rewards
- tighten pitch

Deliverables:

- stable demo path
- screenshots
- demo script

## 9. Technical Scope Recommendation

To move fast, keep the first version simple.

### Recommended MVP

#### Input

- upload receipt image
- optional item scan image

#### Backend output

- OCR text
- cleaned items
- mapped categories
- score per item
- total score
- points
- 2 or 3 suggested swaps

#### Frontend output

- receipt summary
- top bad items
- top good items
- point total
- next best swaps

#### Do not overbuild on day 1

Avoid building these first:

- full user auth
- real coupon partnerships
- advanced reward marketplace
- perfect recycling vision pipeline
- complicated recommendation agents

Those can be described as future work if needed.

## 10. API Contract Recommendation

Define this early so Noel and Warren can build the app shell while Aarav and Sean build ML and scanning in parallel.

### Endpoint 1: receipt scan

`POST /api/scan-receipt`

Input:

```json
{
  "image_url": "or uploaded file reference"
}
```

Output:

```json
{
  "merchant": "Trader Joe's",
  "items": [
    {
      "raw_text": "GRND BF 80/20",
      "normalized_name": "ground beef 80/20",
      "category": "beef",
      "subtype": "ground beef",
      "confidence": 0.94
    }
  ]
}
```

### Endpoint 2: score receipt

`POST /api/score-receipt`

Input:

```json
{
  "items": [
    {
      "normalized_name": "ground beef 80/20",
      "category": "beef"
    }
  ]
}
```

Output:

```json
{
  "ocean_conditions": {
    "region": "Southern California",
    "stress_level": "high",
    "calcofi_signal_summary": "elevated ecosystem stress"
  },
  "items": [
    {
      "name": "ground beef 80/20",
      "category": "beef",
      "climate_impact": 92,
      "runoff_impact": 85,
      "plastic_impact": 20,
      "ocean_score": 18,
      "points": 1,
      "swap_suggestion": {
        "name": "lentils",
        "ocean_score": 86,
        "extra_points": 8,
        "pros": ["lower runoff", "lower climate impact"],
        "cons": ["different taste", "less protein density per serving"]
      }
    }
  ],
  "total_points": 14
}
```

This contract lets frontend and backend move independently.

## 11. Individual Work Plans

## Aarav Plan

### Goal

Build the ML classification and scoring layer that turns scanned items into categories, confidence, and Ocean Score outputs.

### Files Aarav should own

- `backend/classification/*`
- `backend/scoring/*`
- model/output schema docs
- evaluation scripts or notebooks used for classification/scoring checks

### Aarav tasks

1. Decide the first-pass classification approach.
   Recommended:
   - category mapping rules first
   - lightweight ML model only if it clearly improves demo quality
2. Define the category list and confidence rules used by the scoring pipeline.
3. Build category classifier outputs for common grocery items.
4. Implement the item-level scoring logic and total score rollup.
5. Add points mapping and swap suggestion output shape.
6. Connect the scoring pipeline to CalCOFI-based ocean stress weighting.
7. Align the response schema with Sean's scan APIs so frontend can consume one stable payload.

### Aarav should not block on

- polished frontend UI
- final rewards styling
- advanced auth or account systems

Use sample scanned items first.

## Noel Plan

### Goal

Build a clickable app skeleton that can later connect to Sean and Aarav's APIs.

### Files Noel should own

- `frontend/src/screens/Home.tsx`
- `frontend/src/screens/ReceiptScan.tsx`
- `frontend/src/screens/ItemScan.tsx`
- `frontend/src/lib/*`

### Noel tasks

1. Pick the frontend stack.
   Recommended: `React` or `Next.js` if you want web, `Expo React Native` if you want mobile.
2. Build the basic navigation and shell layout.
3. Build upload/camera UI for item scan and receipt scan.
4. Add mocked loading, success, and error states for scan flows.
5. Define a stable frontend data contract for results pages.
6. When Sean and Aarav's APIs are ready, replace the mock JSON with real API calls.
7. Keep integration helpers isolated so Warren can build on top of the same app shell cleanly.

### Noel should not block on

- real OCR
- real scoring
- final dataset integration

## Warren Plan

### Goal

Own the rest of the app skeleton experience, especially the results, rewards, and demo-facing UI polish.

### Files Warren should own

- `frontend/src/screens/Results.tsx`
- `frontend/src/screens/Rewards.tsx`
- `frontend/src/components/*`
- `docs/product/feature-priority.md`
- `docs/product/user-stories.md`

### Warren tasks

1. Build the results screen UI around the agreed API response shape.
2. Build points and rewards screens.
3. Add the `What if I swapped this?` section and alternative recommendation cards.
4. Create reusable frontend components for score chips, item cards, and points summaries.
5. Define the product copy and user-facing wording for the demo.
6. Prioritize features by `must have`, `nice to have`, and `future`.
7. Keep demo flow and feature-priority docs current as UI decisions change.

## Sean Plan

### Goal

Build the scanning pipeline and scan APIs that feed Aarav's ML and scoring layer.

### Files Sean should own

- `backend/ocr/*`
- `backend/api/scan_receipt.*`
- `backend/api/scan_item.*`
- `data/sample_receipts/*`
- `data/sample_items/*`

### Sean tasks

1. Decide the OCR approach.
   Recommended:
   - fastest: an OCR API or library already available
   - fallback: local OCR pipeline
2. Create sample receipt and item-scan test cases.
3. Build text cleanup functions:
   - uppercase/lowercase normalization
   - merchant noise removal
   - quantity/price stripping
   - abbreviation mapping
4. Build a receipt abbreviation dictionary.

Examples:

- `GRND BF 80/20` -> `ground beef 80/20`
- `ORG BNNS` -> `organic bananas`
- `WHL MLK` -> `whole milk`

5. Expose stable receipt and item scan APIs returning parsed items and confidence.
6. Add a confidence threshold and fallback category:
   - `unknown`
7. Document scanning assumptions and known failure cases in a short backend README.

### Sean stretch goals

- item scan image classification
- crumpled receipt robustness
- confidence score UI support

## 12. Scoring System Recommendation

Use a simple formula for the MVP.

### Step 1: baseline item impacts

Each category gets three values:

- `climate_impact`
- `runoff_impact`
- `plastic_impact`

All on a `0-100` penalty scale where higher is worse.

### Step 2: ocean stress multiplier

Use CalCOFI-derived conditions to adjust the weight on runoff-related harm.

Example:

- normal ocean stress -> runoff weight = `1.0`
- elevated stress -> runoff weight = `1.3`
- severe stress -> runoff weight = `1.6`

### Step 3: final score

Example formula:

```text
raw_penalty =
  (0.4 * climate_impact) +
  (0.4 * runoff_impact * ocean_stress_multiplier) +
  (0.2 * plastic_impact)

ocean_score = max(0, 100 - raw_penalty)
```

### Step 4: points

Example:

- score `80-100` -> 10 points
- score `60-79` -> 6 points
- score `40-59` -> 3 points
- score `<40` -> 1 point

This is simple, explainable, and demo-friendly.

## 13. CalCOFI Integration Plan

Since CalCOFI is not a grocery database, use it like this:

### CalCOFI should power

- current or recent regional ocean stress indicator
- algae/bloom-related ecological stress proxy
- marine ecosystem context shown in the app

### CalCOFI should not be claimed to do

- identify fertilizer brand on a receipt
- directly score a SKU from barcode alone
- prove that one product caused one ocean event

### Safe demo wording

Use wording like:

- `score adjusted for current Southern California ocean stress conditions`
- `runoff-heavy products are penalized more when marine ecosystems are under greater stress`

Avoid wording like:

- `this product caused algal blooms`
- `CalCOFI proves this milk brand harms the ocean`

## 14. Suggested Day Plan

### First 2 hours

- finalize repo structure
- create branches
- pick stack
- agree on API contract
- agree on category list

### Next 4 hours

- Noel: app shell and scan entry screens
- Warren: results and rewards UI
- Sean: OCR pipeline prototype
- Aarav: classifier and scoring prototype

### Next 4 hours

- Sean: API returns parsed receipt categories
- Aarav: scoring pipeline returns item scores and points
- Noel: connect UI to mocked API shape
- Warren: finalize rewards UX and swap flow copy

### Next 4 hours

- integrate scoring engine
- connect CalCOFI context
- polish result screens

### Final block

- bug fixing
- demo video
- README
- pitch prep

## 15. Definition Of Done For Each Area

### Aarav done means

- categories or model outputs work on sample scanned items
- scoring returns item-level scores, total score, and points
- backend response shape is stable for frontend integration

### Noel done means

- user can click through home, receipt scan, and item scan screens
- upload flow exists
- app shell can render mocked backend responses

### Warren done means

- results and rewards screens are demo-ready
- swap suggestions and point summaries are easy to understand
- feature priority and demo copy are clear

### Sean done means

- receipt OCR works on at least 5 to 10 sample receipts
- common abbreviations normalize correctly
- scan APIs return parsed items with confidence

### Team done means

- one full demo flow works end to end
- there is a Scripps dataset story
- pitch is understandable in 30 seconds

## 16. Minimum Demo Flow

Use this for judging:

1. Upload a grocery receipt.
2. App parses items.
3. App classifies beef, dairy, veggies, packaged items, etc.
4. App shows Ocean Score and points.
5. App explains that score is adjusted by current ocean stress conditions from CalCOFI.
6. App suggests 2 better swaps.
7. App shows how many more points those swaps would earn.

That is enough for a strong MVP.

## 17. Nice-To-Have Features If Time Remains

- item scan before checkout
- shopping-list recommendation agent
- “maximize points under budget” planner
- recycling bin photo rewards
- special event bonus campaigns
- trend history for user purchases

## 18. Final Recommendations

- Build the receipt flow first.
- Let Noel and Warren use mocked data on the frontend immediately.
- Have Aarav and Sean lock the scan and score schema early.
- Keep CalCOFI as the Scripps eligibility anchor.
- Keep product scoring category-based, not SKU-perfect.
- Do not overbuild the recycling feature unless the core receipt flow already works.
- Merge small, often.

If the team follows this plan, you should be able to work in parallel with limited overlap and integrate the app into a demoable MVP by the deadline.
