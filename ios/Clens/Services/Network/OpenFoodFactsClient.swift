import Foundation

// Swift port of barcode_to_score() in project_oceanscore.py.
// Given a barcode, fetch product metadata from OpenFoodFacts and hand back
// a FoodItem that OceanScoreEngine can score.
enum OpenFoodFactsClient {

    enum OFFError: Error {
        case network(Int)
        case notFound
        case decoding
    }

    struct OFFResponse: Decodable {
        let status: Int?
        let product: OFFProduct?
    }

    struct OFFProduct: Decodable {
        let product_name: String?
        let brands: String?
        let categories_tags: [String]?
        let labels_tags: [String]?
        let packaging_tags: [String]?
        let origins: String?
        let ingredients_text: String?
    }

    // Match the cat_map in the Python file, but emit our FoodCategory enum.
    private static let categoryMap: [(token: String, category: FoodCategory)] = [
        ("beef", .beef),
        ("ground-beef", .beef),
        ("steak", .beef),
        ("poultry", .poultry),
        ("chicken", .poultry),
        ("turkey", .poultry),
        ("fish", .seafood),
        ("seafood", .seafood),
        ("tuna", .seafood),
        ("salmon", .seafood),
        ("dairies", .dairy),
        ("dairy", .dairy),
        ("milk", .dairy),
        ("cheese", .dairy),
        ("yogurt", .dairy),
        ("butter", .dairy),
        ("legumes", .legumes),
        ("lentils", .legumes),
        ("beans", .legumes),
        ("chickpeas", .legumes),
        ("vegetables", .vegetables),
        ("fresh-vegetables", .vegetables),
        ("fruits", .fruit),
        ("fresh-fruits", .fruit),
        ("cereals", .grains),
        ("breads", .grains),
        ("pastas", .grains),
        ("rice", .grains),
        ("snacks", .packagedSnacks),
        ("sugary-snacks", .packagedSnacks),
        ("biscuits", .packagedSnacks),
        ("chocolates", .packagedSnacks),
        ("spreads", .packagedSnacks),
        ("beverages", .beverages),
        ("sodas", .beverages),
        ("juices", .beverages),
        ("waters", .beverages),
        ("detergents", .household),
        ("household", .household)
    ]

    private static func category(for tags: [String]) -> FoodCategory {
        let lower = tags.map { $0.lowercased() }
        for (token, cat) in categoryMap {
            if lower.contains(where: { $0.contains(token) }) { return cat }
        }
        return .unknown
    }

    private static func packaging(for tags: [String]) -> PackagingType {
        let lower = tags.map { $0.lowercased() }
        if lower.contains(where: { $0.contains("plastic") }) { return .plastic }
        if lower.contains(where: { $0.contains("glass") }) { return .glass }
        if lower.contains(where: { $0.contains("carton") || $0.contains("paper") || $0.contains("cardboard") }) { return .cardboard }
        if lower.contains(where: { $0.contains("can") || $0.contains("aluminium") || $0.contains("aluminum") || $0.contains("tin") }) { return .can }
        if !lower.isEmpty { return .mixed }
        return .unknown
    }

    private static func isOrganic(labels: [String]) -> Bool {
        let lower = labels.map { $0.lowercased() }
        return lower.contains(where: { $0.contains("organic") || $0.contains("bio") })
    }

    static func fetchFoodItem(barcode: String) async throws -> FoodItem {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            throw OFFError.notFound
        }
        var request = URLRequest(url: url)
        request.setValue("Clens/0.1 (datahacks2026)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OFFError.network(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
        guard decoded.status == 1, let product = decoded.product else {
            throw OFFError.notFound
        }

        let cat = category(for: product.categories_tags ?? [])
        let pkg = packaging(for: product.packaging_tags ?? [])
        let organic = isOrganic(labels: product.labels_tags ?? [])
        let ingredients = (product.ingredients_text ?? "")
            .split(whereSeparator: { ",;()[]".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(5)

        return OceanScoreEngine.foodItem(
            name: product.product_name ?? "Unknown product",
            brand: product.brands?.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? "",
            category: cat,
            barcode: barcode,
            isOrganic: organic,
            isLocal: false,
            packaging: pkg,
            classificationConfidence: cat == .unknown ? 0.35 : 0.7,
            keyIngredients: Array(ingredients),
            sourceOrigin: product.origins
        )
    }
}
