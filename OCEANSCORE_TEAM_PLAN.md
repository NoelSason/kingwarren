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

### Aarav

Primary responsibility:

- app skeleton
- navigation
- camera/upload UI
- receipt and item scan flow
- points and rewards UI

Should mostly own:

- `frontend/`
- shared UI components
- screens/pages

### Noel

Primary responsibility:

- OCR pipeline
- receipt text cleaning
- abbreviation handling
- product classification
- API endpoints for scan results

Should mostly own:

- `backend/ocr/`
- `backend/classification/`
- `backend/api/scan`

### Warren

Primary responsibility:

- feature brainstorming
- product logic
- score rules
- reward ideas
- alternative recommendations logic
- guardrails for recycling photo feature
- user stories and presentation language

Should mostly own:

- `docs/`
- `data/score_rules/`
- `prompts/`
- product spec files and feature prioritization docs

### Shared responsibilities

Everyone should help with:

- testing
- demo preparation
- README
- bug fixes on their own area

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

- Aarav owns `frontend/`
- Noel owns `backend/ocr/`, `backend/classification/`, and scan APIs
- Warren owns `docs/` and `data/score_rules/`
- Shared logic for final integration can live in `backend/scoring/`, but one person should be designated as the editor for each file

## 4. Branch Strategy

You should not all work on `main`.

### Branch naming

Use short, consistent branch names:

- `aarav/app-skeleton`
- `noel/ocr-classifier`
- `warren/feature-spec`
- later integration branches:
  - `noel/scoring-api`
  - `aarav/scan-ui-integration`
  - `warren/rewards-logic-docs`

### One-time setup for everyone

Run this after cloning or opening the repo:

```bash
git checkout main
git pull origin main
```

### Create a branch

Example for Aarav:

```bash
git checkout main
git pull origin main
git checkout -b aarav/app-skeleton
```

Example for Noel:

```bash
git checkout main
git pull origin main
git checkout -b noel/ocr-classifier
```

Example for Warren:

```bash
git checkout main
git pull origin main
git checkout -b warren/feature-spec
```

### Push your branch to GitHub

After the first commit on a branch:

```bash
git push -u origin <branch-name>
```

Example:

```bash
git push -u origin noel/ocr-classifier
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

- `create frontend scan flow skeleton`
- `add receipt OCR preprocessing pipeline`
- `write scoring rules draft and feature spec`
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

- Aarav edits frontend integration files
- Noel exposes stable backend endpoints
- Warren updates docs/spec only

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

- Aarav builds UI skeleton
- Noel builds OCR + product classification
- Warren defines score rules and features

Deliverables:

- navigable app shell
- a working OCR prototype on sample receipts
- draft scoring rules and reward logic

### Phase 3: Scoring integration

Goal:

- connect classification output to Ocean Score engine
- connect score engine to CalCOFI-based ocean multiplier

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

Define this early so Aarav and Noel can work separately.

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

Build a clickable app skeleton that can later connect to Noel's APIs.

### Files Aarav should own

- `frontend/src/screens/Home.tsx`
- `frontend/src/screens/ReceiptScan.tsx`
- `frontend/src/screens/ItemScan.tsx`
- `frontend/src/screens/Results.tsx`
- `frontend/src/screens/Rewards.tsx`
- `frontend/src/components/*`

### Aarav tasks

1. Pick frontend stack.
   Recommended: `React` or `Next.js` if you want web, `Expo React Native` if you want mobile.
2. Build the basic navigation.
3. Build upload/camera UI for item scan and receipt scan.
4. Build fake results screen using mocked JSON.
5. Build points/rewards UI.
6. Add a `What if I swapped this?` section on the results page.
7. When Noel's API is ready, replace the mock JSON with real API calls.

### Aarav should not block on

- real OCR
- real scoring
- real dataset integration

Use mock data first.

## Noel Plan

### Goal

Build the OCR and product classification pipeline.

### Files Noel should own

- `backend/ocr/*`
- `backend/classification/*`
- `backend/api/scan_receipt.*`
- `backend/api/scan_item.*`

### Noel tasks

1. Decide OCR approach.
   Recommended:
   - fastest: an OCR API or library already available
   - fallback: local OCR pipeline
2. Create sample receipt test cases in `data/sample_receipts/`.
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

5. Build category classifier:
   - beef
   - dairy
   - poultry
   - seafood
   - vegetables
   - fruit
   - legumes
   - packaged snacks
   - beverages
6. Expose a stable API returning parsed items and confidence.
7. Add a confidence threshold and fallback category:
   - `unknown`
8. Document assumptions in a short backend README.

### Noel stretch goals

- item scan image classification
- crumpled receipt robustness
- confidence score UI support

## Warren Plan

### Goal

Define the app logic, rules, feature priorities, and guardrails so the team does not guess.

### Files Warren should own

- `docs/product/feature-priority.md`
- `docs/product/user-stories.md`
- `docs/product/reward-system.md`
- `data/score_rules/item-impact-rules.json`
- `docs/research/recycling-guardrails.md`

### Warren tasks

1. Write top 3 user personas.

Examples:

- budget-conscious grocery shopper
- eco-conscious student
- family trying to make healthier and cheaper swaps

2. Define score dimensions:
   - climate impact
   - runoff impact
   - plastic impact
3. Draft category-level scoring priors.

Example:

- beef = high climate, high runoff
- leafy vegetables = low climate, low runoff
- heavily packaged snack = moderate climate, high plastic

4. Define reward mechanics:
   - points per receipt
   - streaks
   - double-point events
   - reward unlock examples
5. Define `What if` feature behavior:
   - suggested replacement
   - extra points gained
   - pros and cons
6. Write guardrails for recycling-photo feature.

Examples:

- require photo plus bin-type prompt
- allow only limited daily submissions
- no duplicate photo hashes
- no points without confidence threshold

7. Prioritize features by `must have`, `nice to have`, `future`.

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

- Aarav: UI skeleton with mocked data
- Noel: OCR pipeline prototype
- Warren: feature and score rule docs

### Next 4 hours

- Noel: API returns parsed categories
- Aarav: connect UI to mocked API shape
- Warren: finalize reward logic and swap rules

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

- user can click through all major screens
- receipt upload flow exists
- results screen displays real backend response

### Noel done means

- receipt OCR works on at least 5 to 10 sample receipts
- common abbreviations normalize correctly
- item categories return with confidence

### Warren done means

- score rules exist in writing
- feature priority is clear
- rewards and guardrails are defined

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
- Use mocked data on the frontend immediately.
- Keep CalCOFI as the Scripps eligibility anchor.
- Keep product scoring category-based, not SKU-perfect.
- Do not overbuild the recycling feature unless the core receipt flow already works.
- Merge small, often.

If the team follows this plan, you should be able to work in parallel with limited overlap and integrate the app into a demoable MVP by the deadline.
