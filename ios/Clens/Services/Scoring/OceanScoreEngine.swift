import Foundation

// Scoring engine for the app. Produces a score, points, and a UI-ready
// Product from a backend FoodItem + a current ocean-stress index.
//
// Formula per CLAUDE.md (and what Sean's pipeline expects to feed):
//   raw_penalty = 0.4*climate + 0.4*runoff*stress + 0.2*plastic
//   ocean_score = max(0, 100 - raw_penalty)
//
// FoodItem impacts are already 0-100 penalty values with organic/local/
// packaging modifiers applied by the backend. If the app received a raw
// FoodItem (e.g. from OpenFoodFacts without label signals) we apply the
// same modifiers here so both paths converge.
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
            hasPlasticPackaging: nil,
            rawLabelText: "",
            barcode: barcode,
            sourceOrigin: sourceOrigin
        )
    }

    static func score(_ item: FoodItem, stressIndex: Double) -> Scored {
        let score: Int
        if let co2Kg = item.agribalyseCO2Kg, let ef = item.agribalyseEF {
            // Cell 8 score_real() from project_oceanscore.py.
            let co2        = 1.0 - min(co2Kg / 30.0, 1.0)
            let efNorm     = 1.0 - min(ef / 1.0, 1.0)
            let runoff     = efNorm * (2.0 - stressIndex) / 2.0
            let plasticTerm = (item.hasPlasticPackaging ?? false) ? 0.3 : 1.0
            let composite  = 0.30 * co2 + 0.30 * runoff + 0.20 * plasticTerm + 0.20 * efNorm
            score = max(0, min(100, Int((100.0 * composite).rounded())))
            ScanLog.step(12, "scoring branch=AGRIBALYSE (Cell 8 formula)")
            ScanLog.step(13, String(format: "  co2=%.2f ef_norm=%.2f runoff=%.2f plastic_term=%.2f → composite=%.3f → score=%d",
                                    co2, efNorm, runoff, plasticTerm, composite, score))
        } else {
            // Category-baseline fallback (receipts, unknown SKUs).
            let climate = Double(item.climateImpact)
            let runoff  = Double(item.runoffImpact)
            let plastic = Double(item.plasticImpact)
            let rawPenalty = 0.4 * climate
                           + 0.4 * runoff * stressIndex
                           + 0.2 * plastic
            score = max(0, Int((100.0 - rawPenalty).rounded()))
            ScanLog.step(12, "scoring branch=CATEGORY-BASELINE (Cell 6 formula)")
            ScanLog.step(13, String(format: "  climate=%.0f runoff=%.0f*stress(%.2f) plastic=%.0f → penalty=%.2f → score=%d",
                                    climate, runoff, stressIndex, plastic, rawPenalty, score))
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
            // Mirror the Cell 8 factor math so the bars track the final score.
            let co2 = 1.0 - min(co2Kg / 30.0, 1.0)
            let efNorm = 1.0 - min(ef / 1.0, 1.0)
            let runoff = efNorm * (2.0 - stressIndex) / 2.0
            let plasticTerm = (item.hasPlasticPackaging ?? false) ? 0.3 : 1.0
            let waterLiters = CategoryImpacts.waterLitersPerKg[item.category] ?? 2000
            let waterDisp = max(0, 100 - min(100, Int(Double(waterLiters) / 200.0)))
            let bClimate = Int((100.0 * co2).rounded())
            let bRunoff = Int((100.0 * runoff).rounded())
            let bPlastic = Int((100.0 * plasticTerm).rounded())
            ScanLog.step(15, "breakdown (agribalyse): climate=\(bClimate) runoff=\(bRunoff) plastic=\(bPlastic) water=\(waterDisp)")
            return Product.Breakdown(
                climate: bClimate,
                runoff:  bRunoff,
                plastic: bPlastic,
                water:   waterDisp
            )
        }
        let climateDisp = max(0, 100 - item.climateImpact)
        let runoffPenalty = Int((Double(item.runoffImpact) * stressIndex).rounded())
        let runoffDisp = max(0, min(100, 100 - runoffPenalty))
        let plasticDisp = max(0, 100 - item.plasticImpact)
        let waterLiters = CategoryImpacts.waterLitersPerKg[item.category] ?? 2000
        let waterPenalty = min(100, Int(Double(waterLiters) / 200.0))
        let waterDisp = max(0, 100 - waterPenalty)
        ScanLog.step(15, "breakdown (category baseline): climate=\(climateDisp) runoff=\(runoffDisp) plastic=\(plasticDisp) water=\(waterDisp)")
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
            badges: [badge]
        )
    }
}
