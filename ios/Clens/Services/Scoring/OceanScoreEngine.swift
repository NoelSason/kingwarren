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

    // Agribalyse EF single-score distribution is heavy-right-tailed: the ~95th
    // percentile lands near 1.5 and the absolute worst (beef / lamb) reaches
    // ~2.5. Normalizing against 2.5 keeps typical products in the usable
    // middle of the scale while still saturating the genuine worst case.
    private static let worstAgribalyseEF: Double = 2.5
    private static let worstAgribalyseCO2: Double = 30.0

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

    static func score(_ item: FoodItem, stressIndex: Double) -> Scored {
        let score: Int
        if let co2Kg = item.agribalyseCO2Kg, let ef = item.agribalyseEF {
            let f = agribalyseFactors(
                co2Kg: co2Kg, ef: ef,
                plasticScore: item.plasticScore,
                waterScore: item.waterScore,
                stressIndex: stressIndex
            )
            score = f.score
            ScanLog.step(12, "scoring branch=AGRIBALYSE (climate/water sqrt-compressed, runoff/plastic S-curved, stress∈[0.8,1.2])")
            ScanLog.step(13, String(format: "  co2=%.2f runoff=%.2f plastic=%.2f water=%.2f stress=%.2f → score=%d",
                                    f.co2, f.runoff, f.plastic, f.water, stressIndex, score))
        } else {
            let f = categoryFactors(for: item.category, stressIndex: stressIndex)
            score = f.score
            ScanLog.step(12, "scoring branch=CATEGORY-BASELINE (climate/water sqrt-compressed, runoff/plastic S-curved, stress∈[0.8,1.2])")
            ScanLog.step(13, String(format: "  co2=%.2f runoff=%.2f plastic=%.2f water=%.2f stress=%.2f → score=%d",
                                    f.co2, f.runoff, f.plastic, f.water, stressIndex, score))
        }
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
        let f: CategoryFactors
        let branch: String
        if let co2Kg = item.agribalyseCO2Kg, let ef = item.agribalyseEF {
            f = agribalyseFactors(
                co2Kg: co2Kg, ef: ef,
                plasticScore: item.plasticScore,
                waterScore: item.waterScore,
                stressIndex: stressIndex
            )
            branch = "agribalyse"
        } else {
            f = categoryFactors(for: item.category, stressIndex: stressIndex)
            branch = "category"
        }
        let bClimate = Int((100.0 * f.co2).rounded())
        let bRunoff  = Int((100.0 * f.runoff).rounded())
        let bPlastic = Int((100.0 * f.plastic).rounded())
        let bWater   = Int((100.0 * f.water).rounded())
        ScanLog.step(15, "breakdown (\(branch)): climate=\(bClimate) runoff=\(bRunoff) plastic=\(bPlastic) water=\(bWater)")
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
