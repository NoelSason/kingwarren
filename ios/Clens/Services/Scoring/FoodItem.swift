import Foundation

// Mirrors the Python dataclass in project_oceanscore.py:scan_label_image().
// Any backend (Claude Vision, OpenFoodFacts adapter, receipt OCR, Sean's ML
// pipeline) should return values in this shape so the scoring engine and
// UI adapter don't care where the data came from.
struct FoodItem: Codable, Hashable {
    // Label-extracted identity
    var normalizedName: String
    var brand: String
    var category: FoodCategory
    var classificationConfidence: Double

    // Label-derived signals
    var isOrganic: Bool
    var isLocal: Bool
    var packagingType: PackagingType
    var keyIngredients: [String]

    // 0-100 penalty scale, higher = worse (matches Python convention).
    // Used when Agribalyse data is absent (receipts, unknown products).
    var climateImpact: Int
    var runoffImpact: Int
    var plasticImpact: Int

    // Per-SKU Agribalyse lifecycle signals from OpenFoodFacts ecoscore_data,
    // used by the Cell 8 score_real() path in project_oceanscore.py. When
    // present they override the category-baseline scoring.
    var agribalyseCO2Kg: Double?       // kg CO2-eq per kg product
    var agribalyseEF: Double?          // environmental footprint, typically 0-1.5
    var hasPlasticPackaging: Bool?     // detected from packagings[].material

    // Optional provenance
    var rawLabelText: String
    var barcode: String?
    var sourceOrigin: String?

    static func unknown(name: String = "Unknown product", barcode: String? = nil) -> FoodItem {
        let base = CategoryImpacts.baseline[.unknown]!
        return FoodItem(
            normalizedName: name,
            brand: "",
            category: .unknown,
            classificationConfidence: 0.0,
            isOrganic: false,
            isLocal: false,
            packagingType: .unknown,
            keyIngredients: [],
            climateImpact: base.climate,
            runoffImpact: base.runoff,
            plasticImpact: base.plastic,
            agribalyseCO2Kg: nil,
            agribalyseEF: nil,
            hasPlasticPackaging: nil,
            rawLabelText: "",
            barcode: barcode,
            sourceOrigin: nil
        )
    }
}

enum FoodCategory: String, Codable, CaseIterable, Hashable {
    case beef
    case dairy
    case poultry
    case seafood
    case vegetables
    case fruit
    case legumes
    case grains
    case packagedSnacks = "packaged snacks"
    case beverages
    case household
    case unknown

    init(rawLoose value: String) {
        let normalized = value.lowercased().trimmingCharacters(in: .whitespaces)
        self = FoodCategory(rawValue: normalized) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .packagedSnacks: return "Packaged snacks"
        default: return rawValue.capitalized
        }
    }

    // Short section label used in the UI (ScanResultView "Meat · Refrigerated")
    var sectionLabel: String {
        switch self {
        case .beef, .poultry:   return "Meat · Refrigerated"
        case .seafood:          return "Seafood · Fresh"
        case .dairy:            return "Dairy · Refrigerated"
        case .vegetables:       return "Produce · Fresh"
        case .fruit:            return "Produce · Fresh"
        case .legumes:          return "Legume · Dry"
        case .grains:           return "Grain · Dry"
        case .packagedSnacks:   return "Packaged · Snack"
        case .beverages:        return "Beverage · Canned"
        case .household:        return "Household"
        case .unknown:          return "Grocery"
        }
    }
}

enum PackagingType: String, Codable, CaseIterable, Hashable {
    case plastic
    case cardboard
    case glass
    case can
    case mixed
    case unknown

    init(rawLoose value: String) {
        let normalized = value.lowercased().trimmingCharacters(in: .whitespaces)
        self = PackagingType(rawValue: normalized) ?? .unknown
    }
}
