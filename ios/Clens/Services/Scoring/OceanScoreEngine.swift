import Foundation

// Scoring engine for the app. Mirrors project_oceanscore.py:
//   • Cell 8 score_real() — Agribalyse / LLM-estimated per-SKU lifecycle data.
//   • Cell 6 ocean_score() — category-baseline fallback from the IMPACTS table.
// The Agribalyse branch wins whenever co2_total + ef_total are present; otherwise
// we fall back to the category formula, matching the Python barcode_to_score flow.
enum OceanScoreEngine {

    struct Scored {
        let foodItem: FoodItem
        let stressIndex: Double
        let score: Int          // 0-100, higher = better
        let points: Int         // raw per-item tier points (per CLAUDE.md tiers)
        let displayPoints: Int  // what the UI shows at checkout (score * 1.6)
    }

    // Apply organic / local / packaging modifiers to a baseline triplet.
    // Mirrors _apply_impact_modifiers() in project_oceanscore.py.
    static func applyLabelModifiers(
        _ base: CategoryImpacts.Triplet,
        isOrganic: Bool,
        isLocal: Bool,
        packaging: PackagingType
    ) -> CategoryImpacts.Triplet {
        var climate = base.climate
        var runoff = base.runoff
        var plastic = base.plastic

        if isOrganic {
            runoff = max(0, runoff - CategoryImpacts.organicRunoffReduction)
        }
        if isLocal {
            climate = max(0, climate - CategoryImpacts.localClimateReduction)
        }
        let adj = CategoryImpacts.packagingAdjustment[packaging] ?? 0
        plastic = max(0, min(100, plastic + adj))

        return CategoryImpacts.Triplet(climate: climate, runoff: runoff, plastic: plastic)
    }

    // Build a FoodItem from a category + label signals. Used by the
    // OpenFoodFacts barcode path when we don't have full label vision.
    static func foodItem(
        name: String,
        brand: String,
        category: FoodCategory,
        barcode: String?,
        isOrganic: Bool = false,
        isLocal: Bool = false,
        packaging: PackagingType = .unknown,
        classificationConfidence: Double = 0.75,
        keyIngredients: [String] = [],
        sourceOrigin: String? = nil
    ) -> FoodItem {
        let base = CategoryImpacts.baseline[category] ?? CategoryImpacts.baseline[.unknown]!
        let adjusted = applyLabelModifiers(base, isOrganic: isOrganic, isLocal: isLocal, packaging: packaging)
        return FoodItem(
            normalizedName: name,
            brand: brand,
            category: category,
            classificationConfidence: classificationConfidence,
            isOrganic: isOrganic,
            isLocal: isLocal,
            packagingType: packaging,
            keyIngredients: keyIngredients,
            climateImpact: adjusted.climate,
            runoffImpact: adjusted.runoff,
            plasticImpact: adjusted.plastic,
            agribalyseCO2Kg: nil,
            agribalyseEF: nil,
            plasticScore: nil,
            waterScore: nil,
            waterLitersPerKg: nil,
            rawLabelText: "",
            barcode: barcode,
            sourceOrigin: sourceOrigin,
            imageFrontURL: nil
        )
    }

    // Stress clamped to [0.8, 1.2]: prevents a stress spike from pinning every
    // factor to zero, and stops pristine-ocean moments from letting high-impact
    // items register as "fine".
    private static func softenStress(_ stress: Double) -> Double {
        max(0.8, min(1.2, stress))
    }

    // Climate + water: most grocery items sit far below the meat/dairy ceiling,
    // so raw intensity is tiny and goodness pins near 1.0 ("everything green").
    // Square-rooting intensity before the penalty pulls typical items off the
    // ceiling — a 2 kg CO2/kg item no longer looks identical to a 0.5 kg one.
    // Tails still clamp at intensity=1, so beef/lamb stay at 0.
    private static func compressedGoodness(_ intensity: Double, stress: Double) -> Double {
        let stretched = sqrt(max(0.0, min(1.0, intensity)))
        return max(0.0, min(1.0, 1.0 - stretched * stress))
    }

    // Runoff + plastic: smootherstep S-curve on goodness (6t⁵-15t⁴+10t³).
    // Derivative peaks at t=0.5 and vanishes at 0 and 1, so items straddling
    // the median spread apart (more discrimination in middle) while clearly-
    // good / clearly-bad items stay planted at their edges (tight at edges).
    private static func sCurvedGoodness(_ intensity: Double, stress: Double) -> Double {
        let raw = max(0.0, min(1.0, 1.0 - intensity * stress))
        return raw * raw * raw * (raw * (raw * 6 - 15) + 10)
    }

    // Agribalyse EF divisor. Tightened from 2.5 → 1.75 so typical processed
    // products (packaged snacks, beverages) no longer collapse near zero
    // intensity and get flagged as runoff-good. See Doritos case: ef=0.26
    // used to normalize to 0.10 and produce runoff-goodness=98; with 1.75 the
    // ratio becomes 0.15 and the S-curve pulls it back toward the middle.
    private static let worstAgribalyseEF: Double = 1.75
    private static let worstAgribalyseCO2: Double = 30.0

    // Water normalization is recentered on the dataset median (about 1.6k L/kg
    // in the curated Agribalyse set). A product whose log-water matches the
    // median maps to intensity 0.5 — i.e. "typical water use". Products far
    // above the median still saturate toward 1 but not as quickly as the old
    // min(L/5000, 1) rule, which was pinning small snack bags at ~0.9 goodness
    // even when their absolute water use was mid-pack.
    private static let waterLogSpread: Double = 1.2   // logistic slope

    private static func waterIntensity(_ litersPerKg: Double) -> Double {
        let x = log(max(litersPerKg, 1.0)) - EnvRegressionModel.waterMedianLog
        // Logistic centered on the median → 0.5 at median, 0 at far-low, 1 at far-high.
        return 1.0 / (1.0 + exp(-waterLogSpread * x))
    }

    // Size scaling: sqrt-dampened so a 1 kg jug penalizes ~sqrt(2) ≈ 1.4×,
    // a 50g snack relaxes to ~0.32×, but the effect is clamped so tiny
    // samples don't score as pristine and industrial-sized packs don't saturate.
    private static func sizeScale(_ sizeKg: Double?) -> Double {
        guard let s = sizeKg, s > 0 else { return 1.0 }
        let ref = EnvRegressionModel.referenceSizeKg
        return max(0.4, min(2.5, sqrt(s / ref)))
    }

    // Four goodness factors (0..1, higher=better) plus the composite 0..100 score.
    // Used by both the agribalyse/Cell-8 path and the category/Cell-6 fallback.
    struct CategoryFactors {
        let co2: Double
        let runoff: Double
        let plastic: Double
        let water: Double
        let score: Int
    }

    static func categoryFactors(for category: FoodCategory, stressIndex: Double) -> CategoryFactors {
        let f = CategoryImpacts.impactFactors[category]
            ?? CategoryImpacts.impactFactors[.vegetables]!
        let co2I     = min(f.co2     / CategoryImpacts.worstCO2,     1.0)
        let runoffI  = min(f.runoff  / CategoryImpacts.worstRunoff,  1.0)
        let plasticI = min(f.plastic / CategoryImpacts.worstPlastic, 1.0)
        let waterI   = min(f.water   / CategoryImpacts.worstWater,   1.0)

        let soft = softenStress(stressIndex)

        let co2     = compressedGoodness(co2I,     stress: soft)
        let water   = compressedGoodness(waterI,   stress: soft)
        let runoff  = sCurvedGoodness(runoffI,     stress: soft)
        let plastic = sCurvedGoodness(plasticI,    stress: soft)

        let composite = 0.35 * co2 + 0.30 * runoff + 0.20 * plastic + 0.15 * water
        let score = max(0, min(100, Int((100.0 * composite).rounded())))
        return CategoryFactors(co2: co2, runoff: runoff, plastic: plastic, water: water, score: score)
    }

    // Cell 8 agribalyse path. Same shape policy as the category branch:
    // climate/water use the sqrt-compressed curve (tighter overall),
    // runoff/plastic use the smootherstep S-curve (middle variability, tight
    // edges). Stress is softened to [0.8, 1.2] before entering either.
    static func agribalyseFactors(
        co2Kg: Double,
        ef: Double,
        plasticScore: Double?,
        waterScore: Double?,
        stressIndex: Double
    ) -> CategoryFactors {
        let co2I     = min(co2Kg / worstAgribalyseCO2, 1.0)
        let efI      = min(ef    / worstAgribalyseEF,  1.0)
        // plasticScore / waterScore are stored as pre-stress goodness values,
        // so invert them to get the raw intensity before re-applying stress.
        let plasticI = 1.0 - (plasticScore ?? 0.5)
        let waterI   = 1.0 - (waterScore ?? 0.5)

        let soft = softenStress(stressIndex)

        let co2     = compressedGoodness(co2I,     stress: soft)
        let water   = compressedGoodness(waterI,   stress: soft)
        let runoff  = sCurvedGoodness(efI,         stress: soft)
        let plastic = sCurvedGoodness(plasticI,    stress: soft)

        let composite = 0.30 * co2 + 0.30 * runoff + 0.25 * plastic + 0.15 * water
        let score = max(0, min(100, Int((100.0 * composite).rounded())))
        return CategoryFactors(co2: co2, runoff: runoff, plastic: plastic, water: water, score: score)
    }

    // Unified model-based scoring path. The regression predicts the four raw
    // intensities from (category, size). When OFF has better per-SKU data
    // (Agribalyse co2, packaging-derived plastic, LLM-estimated water) those
    // values override the model's corresponding field. Final bar goodness is
    // a 50/50 blend of the no-stress goodness and the stress-adjusted
    // goodness, so the stress multiplier still matters but can't dominate.
    static func modelBlendedFactors(for item: FoodItem, stressIndex: Double) -> CategoryFactors {
        let sizeKg = item.sizeKg ?? EnvRegressionModel.referenceSizeKg
        let pred = EnvRegressionModel.predict(category: item.category, sizeKg: sizeKg)

        // Model is the source of truth for runoff and water (the LLM-estimated
        // versions varied run-to-run). Co2 and plastic defer to OFF when the
        // specific SKU has real data:
        //   - agribalyseCO2Kg is measured lifecycle data
        //   - plasticScore is derived from OFF packagings[] (material flags +
        //     non-recyclable markers). Critical: it knows a Monster can is
        //     aluminum, so we don't penalize it as if it were a plastic bottle.
        // Packaging type provides a final guardrail — cans and glass cap
        // plastic intensity at a low value regardless of what the model says.
        let co2Kg       = item.agribalyseCO2Kg ?? pred.co2Kg
        let runoffI_raw = pred.runoffIntensity
        var plasticI_raw: Double = {
            if let s = item.plasticScore { return 1.0 - s }
            return pred.plasticIntensity
        }()
        switch item.packagingType {
        case .can, .glass: plasticI_raw = min(plasticI_raw, 0.15)
        case .cardboard:   plasticI_raw = min(plasticI_raw, 0.30)
        default: break
        }
        let waterL      = pred.waterLPerKg

        // Size-scale climate and water intensities (they're per-kg; a bigger
        // package contributes more total impact). Runoff stays per-kg (a
        // farming attribute, independent of pack size). Plastic packaging
        // intensity already tracks packaging, not contents, so leave it too.
        let scale = sizeScale(item.sizeKg)
        let co2I     = min(co2Kg * scale / worstAgribalyseCO2, 1.0)
        let waterI   = min(waterIntensity(waterL * scale), 1.0)
        let runoffI  = min(1.0, max(0.0, runoffI_raw))
        let plasticI = min(1.0, max(0.0, plasticI_raw))

        let soft = softenStress(stressIndex)
        // Half-weight stress: compute goodness with neutral stress (1.0) and
        // with the soft-clamped actual stress, then blend 50/50.
        func blend(_ intensity: Double, curve: (Double, Double) -> Double) -> Double {
            0.5 * curve(intensity, 1.0) + 0.5 * curve(intensity, soft)
        }
        // Water uses a plain linear goodness. The waterIntensity logistic
        // already centers the distribution on the dataset median, so an
        // additional sqrt compression would just crush mid-pack items.
        func linearGoodness(_ intensity: Double, stress: Double) -> Double {
            max(0.0, min(1.0, 1.0 - intensity * stress))
        }
        let co2     = blend(co2I,     curve: compressedGoodness)
        let water   = blend(waterI,   curve: linearGoodness)
        let runoff  = blend(runoffI,  curve: sCurvedGoodness)
        let plastic = blend(plasticI, curve: sCurvedGoodness)

        let composite = 0.30 * co2 + 0.30 * runoff + 0.25 * plastic + 0.15 * water
        let score = max(0, min(100, Int((100.0 * composite).rounded())))
        ScanLog.step(12, String(format: "model: co2Kg=%.2f runoff=%.2f plasticI=%.2f waterL=%.0f size=%.2fkg scale=%.2f",
                                co2Kg, runoffI_raw, plasticI_raw, waterL, sizeKg, scale))
        return CategoryFactors(co2: co2, runoff: runoff, plastic: plastic, water: water, score: score)
    }

    static func score(_ item: FoodItem, stressIndex: Double) -> Scored {
        let f = modelBlendedFactors(for: item, stressIndex: stressIndex)
        let score = f.score
        ScanLog.step(13, String(format: "  co2=%.2f runoff=%.2f plastic=%.2f water=%.2f stress=%.2f → score=%d",
                                f.co2, f.runoff, f.plastic, f.water, stressIndex, score))
        let tier = tierPoints(for: score)
        let display = Int(Double(score) * 1.6)
        ScanLog.step(14, "score=\(score) tierPoints=\(tier) seabucks(displayPoints)=\(display)")

        return Scored(
            foodItem: item,
            stressIndex: stressIndex,
            score: score,
            points: tier,
            displayPoints: display
        )
    }

    // Per CLAUDE.md: 80-100 -> 10, 60-79 -> 6, 40-59 -> 3, else 1.
    static func tierPoints(for score: Int) -> Int {
        switch score {
        case 80...:      return 10
        case 60..<80:    return 6
        case 40..<60:    return 3
        default:         return 1
        }
    }

    // All four bars are "goodness" on 0..100 (higher = better, lower = worse).
    // Same factor math as score() so the bars always track the composite.
    static func uiBreakdown(from item: FoodItem, stressIndex: Double) -> Product.Breakdown {
        let f = modelBlendedFactors(for: item, stressIndex: stressIndex)
        let bClimate = Int((100.0 * f.co2).rounded())
        let bRunoff  = Int((100.0 * f.runoff).rounded())
        let bPlastic = Int((100.0 * f.plastic).rounded())
        let bWater   = Int((100.0 * f.water).rounded())
        ScanLog.step(15, "breakdown (model+50% stress): climate=\(bClimate) runoff=\(bRunoff) plastic=\(bPlastic) water=\(bWater)")
        return Product.Breakdown(
            climate: bClimate,
            runoff:  bRunoff,
            plastic: bPlastic,
            water:   bWater
        )
    }

    // Adapter: FoodItem + stress -> UI Product model used by ScanResultView.
    static func uiProduct(from item: FoodItem, stressIndex: Double) -> Product {
        let scored = score(item, stressIndex: stressIndex)
        let breakdown = uiBreakdown(from: item, stressIndex: stressIndex)

        var facts: [String] = []
        if item.isOrganic { facts.append("Organic — reduced fertilizer runoff") }
        if item.isLocal   { facts.append("Local / regional sourcing") }
        switch item.packagingType {
        case .plastic:   facts.append("Plastic packaging")
        case .glass:     facts.append("Glass (recyclable)")
        case .cardboard: facts.append("Cardboard packaging")
        case .can:       facts.append("Aluminum can (recyclable)")
        case .mixed:     facts.append("Mixed packaging materials")
        case .unknown:   break
        }
        if !item.keyIngredients.isEmpty {
            let top = item.keyIngredients.prefix(3).joined(separator: ", ")
            facts.append("Ingredients: \(top)")
        }
        if facts.isEmpty {
            facts.append("Category: \(item.category.displayName)")
        }
        ScanLog.step(16, "facts assembled (\(facts.count)): \(facts.joined(separator: " | "))")

        let badge = Score.label(scored.score)

        let displayName = item.normalizedName.isEmpty
            ? "Unknown product"
            : item.normalizedName.prefix(1).uppercased() + item.normalizedName.dropFirst()

        // Stable-ish UI id: prefer barcode, fall back to a slug of the name.
        let id = item.barcode
            ?? item.normalizedName.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        return Product(
            id: id.isEmpty ? "scanned-\(UUID().uuidString.prefix(6))" : id,
            name: String(displayName),
            brand: item.brand.isEmpty ? "Unknown brand" : item.brand,
            size: "—",
            score: scored.score,
            category: item.category.sectionLabel,
            breakdown: breakdown,
            facts: facts,
            origin: item.sourceOrigin ?? "—",
            badges: [badge],
            imageURL: item.imageFrontURL
        )
    }
}
