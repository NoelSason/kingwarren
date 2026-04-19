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

    // Coarse water-use priors (liters per kg equivalent). Shaun's IMPACTS table
    // in project_oceanscore.py includes these; we keep them for UI display only.
    static let waterLitersPerKg: [FoodCategory: Int] = [
        .beef: 15400,
        .poultry: 4300,
        .dairy: 1020,
        .seafood: 3700,
        .legumes: 4055,
        .vegetables: 322,
        .fruit: 962,
        .grains: 1800,
        .packagedSnacks: 2000,
        .beverages: 600,
        .household: 1500,
        .unknown: 2000
    ]

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
