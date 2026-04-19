import Foundation

// Baseline impact priors, directly mirroring CATEGORY_IMPACTS in
// project_oceanscore.py. Values are 0-100 penalty scale (higher = worse).
// When Sean/Aarav's backend is ready this table should come from there
// and be injected at app launch — the engine doesn't assume these are static.
enum CategoryImpacts {
    struct Triplet: Hashable {
        var climate: Int
        var runoff: Int
        var plastic: Int
    }

    static let baseline: [FoodCategory: Triplet] = [
        .beef:           Triplet(climate: 92, runoff: 85, plastic: 20),
        .dairy:          Triplet(climate: 65, runoff: 70, plastic: 40),
        .poultry:        Triplet(climate: 45, runoff: 50, plastic: 30),
        .seafood:        Triplet(climate: 30, runoff: 20, plastic: 50),
        .vegetables:     Triplet(climate: 15, runoff: 35, plastic: 25),
        .fruit:          Triplet(climate: 18, runoff: 30, plastic: 30),
        .legumes:        Triplet(climate: 10, runoff: 20, plastic: 20),
        .grains:         Triplet(climate: 20, runoff: 25, plastic: 15),
        .packagedSnacks: Triplet(climate: 40, runoff: 30, plastic: 75),
        .beverages:      Triplet(climate: 25, runoff: 20, plastic: 80),
        .household:      Triplet(climate: 35, runoff: 60, plastic: 85),
        .unknown:        Triplet(climate: 50, runoff: 50, plastic: 50)
    ]

    // Mirrors the IMPACTS dict in project_oceanscore.py Cell 6 (plus pork/eggs/
    // grain/nuts added in Cell 8). co2 is kg CO2-eq per kg product, runoff and
    // plastic are 0-1 factors, water is L per kg. Used by the Cell 6
    // ocean_score() formula when Agribalyse data is unavailable.
    struct ImpactFactors: Hashable {
        var co2: Double
        var runoff: Double
        var plastic: Double
        var water: Double
    }

    static let impactFactors: [FoodCategory: ImpactFactors] = [
        .beef:           ImpactFactors(co2: 99.5, runoff: 0.95, plastic: 0.3, water: 15400),
        .poultry:        ImpactFactors(co2: 9.9,  runoff: 0.55, plastic: 0.4, water: 4300),
        .legumes:        ImpactFactors(co2: 0.9,  runoff: 0.15, plastic: 0.2, water: 4055),
        .vegetables:     ImpactFactors(co2: 2.0,  runoff: 0.25, plastic: 0.4, water: 322),
        .seafood:        ImpactFactors(co2: 13.6, runoff: 0.25, plastic: 0.6, water: 3700),
        .dairy:          ImpactFactors(co2: 9.8,  runoff: 0.80, plastic: 0.5, water: 1020),
        .fruit:          ImpactFactors(co2: 1.1,  runoff: 0.20, plastic: 0.4, water: 962),
        .grains:         ImpactFactors(co2: 2.7,  runoff: 0.35, plastic: 0.3, water: 1600),
        .packagedSnacks: ImpactFactors(co2: 5.0,  runoff: 0.40, plastic: 0.8, water: 2000),
        .beverages:      ImpactFactors(co2: 5.0,  runoff: 0.40, plastic: 0.8, water: 2000),
        .household:      ImpactFactors(co2: 5.0,  runoff: 0.40, plastic: 0.8, water: 2000)
        // .unknown intentionally omitted — callers fall back to .vegetables
        // to match Python's IMPACTS.get(category, IMPACTS["vegetable"]).
    ]

    // WORST constants from Cell 6 — used to normalize each factor.
    static let worstCO2: Double = 30
    static let worstRunoff: Double = 0.6
    static let worstPlastic: Double = 0.6
    static let worstWater: Double = 5000

    // Liters-per-kg lookup derived from impactFactors for UI display.
    static var waterLitersPerKg: [FoodCategory: Int] {
        var out: [FoodCategory: Int] = [:]
        for (cat, f) in impactFactors {
            out[cat] = Int(f.water)
        }
        out[.unknown] = Int(impactFactors[.vegetables]?.water ?? 2000)
        return out
    }

    // Modifier constants match Python file defaults.
    static let organicRunoffReduction: Int = 15
    static let localClimateReduction: Int = 10

    static let packagingAdjustment: [PackagingType: Int] = [
        .plastic:    +10,
        .glass:      -15,
        .cardboard:  -10,
        .can:         -5,
        .mixed:       +5,
        .unknown:      0
    ]
}
