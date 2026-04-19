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

    // Cell 6 ocean_score(category, stress_idx) from project_oceanscore.py.
    // Returns the four component factors (0-1, higher = better) plus the
    // composite 0-100 score so both score() and uiBreakdown() share the math.
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
        let co2     = 1.0 - min(f.co2 / CategoryImpacts.worstCO2, 1.0)
        let runoff  = 1.0 - min((f.runoff * stressIndex) / (CategoryImpacts.worstRunoff * 1.5), 1.0)
        let plastic = 1.0 - f.plastic
        let water   = 1.0 - min(f.water / CategoryImpacts.worstWater, 1.0)
        let composite = 0.35 * co2 + 0.30 * runoff + 0.20 * plastic + 0.15 * water
        let score = max(0, min(100, Int((100.0 * composite).rounded())))
        return CategoryFactors(co2: co2, runoff: runoff, plastic: plastic, water: water, score: score)
    }

    static func score(_ item: FoodItem, stressIndex: Double) -> Scored {
        let score: Int
        if let co2Kg = item.agribalyseCO2Kg, let ef = item.agribalyseEF {
            // Cell 8 score_real() from project_oceanscore.py.
            //   0.30*co2 + 0.30*runoff + 0.25*plastic_score + 0.15*water_score
            let co2Term    = 1.0 - min(co2Kg / 30.0, 1.0)
            let efNorm     = 1.0 - min(ef / 1.0, 1.0)
            let runoffTerm = efNorm * (2.0 - stressIndex) / 2.0
            let plasticScore = item.plasticScore ?? 0.5
            let waterScore   = item.waterScore ?? 0.5
            let composite  = 0.30 * co2Term + 0.30 * runoffTerm + 0.25 * plasticScore + 0.15 * waterScore
            score = max(0, min(100, Int((100.0 * composite).rounded())))
            ScanLog.step(12, "scoring branch=AGRIBALYSE (Cell 8 formula, nuanced plastic + water)")
            ScanLog.step(13, String(format: "  co2=%.2f ef_norm=%.2f runoff=%.2f plastic_score=%.2f water_score=%.2f → composite=%.3f → score=%d",
                                    co2Term, efNorm, runoffTerm, plasticScore, waterScore, composite, score))
        } else {
            // Category-baseline fallback — Cell 6 ocean_score().
            let f = categoryFactors(for: item.category, stressIndex: stressIndex)
            score = f.score
            ScanLog.step(12, "scoring branch=CATEGORY-BASELINE (Cell 6 ocean_score)")
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

    // Convert backend penalty (higher=worse) to UI breakdown value (higher=better)
    // so the existing ScanResultView breakdown row renders naturally.
    static func uiBreakdown(from item: FoodItem, stressIndex: Double) -> Product.Breakdown {
        if let co2Kg = item.agribalyseCO2Kg, let ef = item.agribalyseEF {
            // Mirrors the Cell 8 factor math so bars track the final score.
            let co2 = 1.0 - min(co2Kg / 30.0, 1.0)
            let efNorm = 1.0 - min(ef / 1.0, 1.0)
            let runoff = efNorm * (2.0 - stressIndex) / 2.0
            let plasticScore = item.plasticScore ?? 0.5
            let waterScore   = item.waterScore ?? 0.5
            let bClimate = Int((100.0 * co2).rounded())
            let bRunoff  = Int((100.0 * runoff).rounded())
            let bPlastic = Int((100.0 * plasticScore).rounded())
            let bWater   = Int((100.0 * waterScore).rounded())
            ScanLog.step(15, "breakdown (agribalyse): climate=\(bClimate) runoff=\(bRunoff) plastic=\(bPlastic) water=\(bWater)")
            return Product.Breakdown(
                climate: bClimate,
                runoff:  bRunoff,
                plastic: bPlastic,
                water:   bWater
            )
        }
        // Cell 6 ocean_score() component factors → UI bars (0-100, higher = better).
        let f = categoryFactors(for: item.category, stressIndex: stressIndex)
        let climateDisp = Int((100.0 * f.co2).rounded())
        let runoffDisp  = Int((100.0 * f.runoff).rounded())
        let plasticDisp = Int((100.0 * f.plastic).rounded())
        let waterDisp   = Int((100.0 * f.water).rounded())
        ScanLog.step(15, "breakdown (Cell 6): climate=\(climateDisp) runoff=\(runoffDisp) plastic=\(plasticDisp) water=\(waterDisp)")
        return Product.Breakdown(
            climate: climateDisp,
            runoff:  runoffDisp,
            plastic: plasticDisp,
            water:   waterDisp
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
