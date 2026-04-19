# CLAUDE.md

This file gives AI coding agents the current working context for this repository.

## Repository State

- This repo is still pre-code. Right now it mainly contains planning docs in `docs/`.
- There is no confirmed app stack yet. Do not assume SwiftUI, React Native, Expo, or backend tooling until the repo actually contains it or the user explicitly says so.
- There is no package manager, lockfile, lint, build, or test setup to rely on yet.
- Before running commands, inspect what the team has added and work from the current repo state.

## Project Identity

- Name: `CLENS`
- Former working name: `OceanScore`
- Platform: `iPhone app`
- Theme: `environmental sciences` and `climate change`
- Reward currency: `sea bucks`
- Short pitch: users scan grocery receipts or products, receive an `OceanScore` from `0-100`, earn `sea bucks`, and get better swap suggestions plus rewards.
- Product framing: users care about rewards, savings, and easy swaps first; the ocean science is the scoring engine and story behind those incentives.
- Inspiration: similar consumer behavior loop as `Yuka`, but focused on grocery choices, ocean-aware impact scoring, and rewards.

## Core Product Thesis

The app rewards grocery purchases that are indirectly better for the environment and oceans.

High-level intuition:

- beef / runoff-heavy / plastic-heavy products score worse
- vegetables / lower-impact / lower-runoff products score better
- the app reacts to current ocean stress, so the same category can be penalized more when marine conditions are worse
- the output is not just a score; it should also explain how the user could do better next time

The score should combine:

- climate impact
- runoff impact
- plastic impact
- optional refinements if available: food category, packaging type, processed vs. fresh, farming method, shipping distance, and water use

## Primary User Flows

1. Scan a receipt after shopping.
2. Scan a single product while shopping.
3. Parse items, normalize noisy OCR text, and classify abbreviations such as `GRND BF 80/20` into a usable category.
4. Score each item and the whole basket.
5. Award `sea bucks`.
6. Show "what if" swaps, including the extra points a user would have earned.
7. Show pros and cons for suggested alternatives.
8. Sync profile, rewards, and leaderboard state through Supabase.

## MVP Screens

- `Home`
  - activity feed style summary, for example: `Warren earned 431 points at Whole Foods Market`
  - short explanation of how recent purchases helped or hurt
  - suggestions for improvement
- `Scanning`
  - `Scan receipt`
  - `Scan product`
- `Profile`
  - user summary
  - history
- `Rewards`
  - available discounts
  - sea bucks balance
- `Leaderboard`
  - total points leaderboard
  - local-area ranking
  - rewards tied to ranking

Navigation should use a bottom tab bar:

- Home
- Profile
- center `+` button opens Scan
- Rewards
- Leaderboard

## Architecture Big Picture

Treat the app as a pipeline, not a monolith.

### Product / receipt scoring pipeline

```text
barcode OR product label image
  -> OpenFoodFacts lookup or OCR fallback
  -> normalized product metadata
  -> static impact factors
  -> ocean-stress multiplier
  -> OceanScore 0-100
  -> points + swap suggestions
```

```text
receipt image
  -> OCR / vision model
  -> line item extraction
  -> abbreviation cleanup + classification
  -> item-level impact lookup
  -> ocean-stress modifier
  -> basket score + sea bucks + alternatives
```

Keep the following seams stable so teammates can work in parallel:

- scan input -> normalized item data
- normalized item data -> scoring engine
- ML ocean stress index -> scoring engine
- scoring output -> frontend screens / Supabase storage

## Scoring Model

Use a simple, explainable MVP formula unless the user explicitly changes it.

Baseline item factors:

- `climate_impact`
- `runoff_impact`
- `plastic_impact`

All are on a `0-100` penalty scale where higher is worse.

Ocean stress should amplify runoff-related harm.

Current working formula:

```text
raw_penalty =
  (0.4 * climate_impact) +
  (0.4 * runoff_impact * ocean_stress_multiplier) +
  (0.2 * plastic_impact)

ocean_score = max(0, 100 - raw_penalty)
```

Current point tiers:

- `80-100` -> `10` points
- `60-79` -> `6` points
- `40-59` -> `3` points
- `<40` -> `1` point

If weights or point tiers change, update both the code and the planning docs.

## Real-Ocean Data Direction

Important: older planning notes used `CalCOFI` as the primary Scripps anchor. The current direction is different.

Current dataset priority:

- primary Scripps dataset: `CCE Mooring data`
- secondary / if time permits: `CalCOFI`

Use the Scripps dataset as a real ocean context layer, not as a grocery database.

Safe use:

- current or recent regional stress indicator
- algal bloom / runoff sensitivity proxy
- pH / dissolved oxygen / chlorophyll / nitrate anomaly context
- score adjustment for current Southern California ocean conditions

Unsafe claims:

- a dataset identified a specific grocery SKU
- a specific item directly caused a specific bloom
- a receipt proves brand-level ocean causality

Safe demo wording:

- `score adjusted for current Southern California ocean stress conditions`
- `runoff-heavy products are penalized more when marine ecosystems are under greater stress`

## ML Plan

Current approach:

- `STL` seasonal decomposition
- robust z-score per variable
- `Isolation Forest` on multivariate residuals

Variables of interest:

- pH
- dissolved oxygen
- chlorophyll
- nitrate / NO3

Why this approach:

- Southern California upwelling has a strong seasonal signature
- removing seasonality helps distinguish "unusual for this time of year" from normal annual cycles
- the model is lightweight and can run fast without GPUs

Planned evaluation:

- held-out forecast accuracy with `RMSE` and `MAE`
- synthetic anomaly injection with `precision`, `recall`, and `F1`
- historical event recovery for the `2014-2016` Northeast Pacific warm anomaly / El Nino period on older `CCE2` deployments `9-11`
- `Spearman` rank correlation against a small hand-labeled product set

Potential future extensions:

- region-aware sourcing logic
- per-region stress instead of one generic California stress factor
- deep learning only if everything else is already working and there is time

## Feature Priority

### Must-have MVP

- receipt scan flow
- product scan flow
- OCR cleanup and category classification
- item-level and basket-level scoring
- sea bucks awarding
- swap suggestions
- stable demoable home / scan / rewards / leaderboard flow

### Important but secondary

- Supabase-backed profile sync
- Supabase-backed leaderboard
- rewards inventory / discount stubs
- local-area ranking

### Stretch goals

- shopping list agent that maximizes points while respecting preferences
- recommendations personalized to likely user swap acceptance
- shopping-type clustering such as convenience, meat-heavy, budget, or low-waste shoppers
- special events such as `2x points` on products that help under current ocean conditions
- recycling / waste-bin photo rewards

Do not let stretch ideas block the receipt-scoring MVP.

## Recycling Feature Guardrails

The recycling photo feature is explicitly a stretch feature and needs guardrails.

Do not build it before the main scan + score loop works.

If implemented, it needs:

- clear accepted waste categories
- confidence thresholds
- anti-abuse checks
- conservative reward rules

Do not make this the main demo path.

## Data Sources And Helpers

Known external inputs:

- `CCE Mooring` data for the ocean stress multiplier
- `CalCOFI` if time permits or as supporting context
- `OpenFoodFacts` for barcode / product metadata lookup
- static product impact priors for CO2, runoff, plastic, and optionally water
- OCR / vision parsing for receipt and label input

Useful project references from the user:

- dataset bank Google Doc
- hacker handbook Google Doc
- `https://www.amentum.io/ocean_docs`
- `https://datahacks-2026.devpost.com/`

## Competition Constraints

These matter for both code and pitch decisions.

- The project is for `DataHacks 2026`.
- For software-based projects, at least one listed dataset must be used as a core part of the project.
- To be eligible for the `$1500 Scripps Challenge`, the project must use a `Scripps` dataset.
- Teams can have `1-4` members.
- A team can submit to up to `2` tracks.
- All project materials must be created during the hackathon timeframe.
- The repo history matters; organizers may inspect GitHub history.

Important deadlines from the handbook:

- team / track registration due `April 18, 2026` at `12:00 PM`
- soft submission due `April 19, 2026` at `12:00 PM`
- hard submission due `April 19, 2026` at `1:00 PM`

## Team Roles

Current role split from the user's latest notes:

- `Aarav`: scanning features
- `Shaun`: machine learning
- `Warren`: product ideas, design, frontend
- `Noel`: frontend coding

Important note:

- older docs assigned OCR / classification ownership to Noel
- the newer role split does not clearly assign OCR / classification
- do not assume ownership for OCR / classification work without checking current team expectations

## Collaboration Rules

- Use branch-per-person naming like `aarav/...`, `shaun/...`, `warren/...`, `noel/...`.
- Do not commit directly to `main`.
- Keep root config changes coordinated.
- One owner per file whenever possible.
- Merge small and often.
- If you touch docs that define product or scoring behavior, keep them in sync with the code.

## Existing Repo Docs

There are two local planning docs that should be treated as important context:

- `docs/OCEANSCORE_TEAM_PLAN.md`
- `docs/DATAHACKS_REQUIREMENTS.md`

How to use them:

- `docs/OCEANSCORE_TEAM_PLAN.md` is useful for folder structure, API shape, scoring, merge workflow, and demo planning
- it is partially outdated on `name`, `platform`, `primary dataset`, and `team roles`
- `docs/DATAHACKS_REQUIREMENTS.md` captures the hackathon rules and is still useful for constraints and deadlines

## Recommended Build Order

1. Lock the app shell and screen skeleton.
2. Lock the scan-to-score API contract.
3. Build receipt parsing with mocked scoring output.
4. Build the scoring engine with static impact priors.
5. Add the ocean-stress multiplier from the Scripps dataset.
6. Add swap suggestions.
7. Add Supabase sync for profile, rewards, and leaderboard.
8. Polish the judging flow and pitch assets.

## Demo Story

The strongest judging flow is:

1. scan a grocery receipt
2. parse line items
3. classify beef / dairy / produce / packaged items
4. show per-item OceanScore plus total sea bucks
5. explain that current ocean stress is influencing runoff penalties
6. suggest better swaps
7. show how many more points those swaps would earn

Pitch emphasis:

- local consumer behavior
- environmental impact translated into personal incentives
- live or recent ocean conditions make the score feel dynamic
- explainable scoring beats overclaiming scientific certainty

## Source Of Truth Rule

- If the user gives newer instructions than this file, the user wins.
- If this file conflicts with the current repo state, the repo state wins for implementation details.
- If `docs/OCEANSCORE_TEAM_PLAN.md` conflicts with the user's newer notes, prefer the user's newer notes.
