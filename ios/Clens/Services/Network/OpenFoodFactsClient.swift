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
        let packagings: [OFFPackaging]?
        let origins: String?
        let ingredients_text: String?
        let ecoscore_data: OFFEcoscoreData?
        let image_front_url: String?
        // product_quantity is grams as a string; quantity is a human label like
        // "240 g" or "1.5 L". Prefer product_quantity, fall back to parsing.
        let product_quantity: String?
        let quantity: String?
    }

    struct OFFPackaging: Decodable {
        let material: String?
        let non_recyclable_and_non_biodegradable: String?
    }

    struct OFFEcoscoreData: Decodable {
        let agribalyse: OFFAgribalyse?
    }

    struct OFFAgribalyse: Decodable {
        let co2_total: Double?
        let ef_total: Double?
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

    // New Cell 8 score_real() plastic gradient. Per packaging entry:
    //   weight 1.0 if material is plastic AND non-recyclable-and-non-biodegradable
    //   weight 0.5 if material contains "plastic" or "pet"
    //   weight 0.0 otherwise
    // plastic_score = max(0, 1 - sum(weights) / count). Returns nil when there
    // are no packagings — caller will fall through to the LLM's plastic_score.
    private static func plasticScore(packagings: [OFFPackaging]?) -> Double? {
        guard let pkgs = packagings, !pkgs.isEmpty else { return nil }
        var total = 0.0
        for pk in pkgs {
            let m = (pk.material ?? "").lowercased()
            let containsPlastic = m.contains("plastic")
            let containsPET = m.contains("pet")
            let flaggedNonRecyclable = (pk.non_recyclable_and_non_biodegradable ?? "").lowercased() == "yes"
            if containsPlastic && flaggedNonRecyclable {
                total += 1.0
            } else if containsPlastic || containsPET {
                total += 0.5
            }
        }
        return max(0.0, 1.0 - total / Double(pkgs.count))
    }

    private static func isOrganic(labels: [String]) -> Bool {
        let lower = labels.map { $0.lowercased() }
        return lower.contains(where: { $0.contains("organic") || $0.contains("bio") })
    }

    // Convert OFF's product_quantity (grams, as a string) or quantity
    // ("240 g", "1.5 L", "12 oz") into kilograms. Liquids are treated as
    // ~1 kg/L which is accurate for water-based beverages and good enough
    // for size-scaling penalties on everything else.
    static func sizeKg(productQuantity: String?, quantity: String?) -> Double? {
        if let pq = productQuantity, let grams = Double(pq.trimmingCharacters(in: .whitespaces)), grams > 0 {
            return grams / 1000.0
        }
        guard let q = quantity?.lowercased() else { return nil }
        // Extract the first number in the string.
        var numStr = ""
        var sawDot = false
        for ch in q {
            if ch.isNumber { numStr.append(ch) }
            else if ch == "." && !sawDot { numStr.append(ch); sawDot = true }
            else if !numStr.isEmpty { break }
        }
        guard let n = Double(numStr), n > 0 else { return nil }
        if q.contains("kg") { return n }
        if q.contains("mg") { return n / 1_000_000.0 }
        if q.contains("g") { return n / 1000.0 }
        if q.contains("ml") { return n / 1000.0 }   // assume ~1 g/mL
        if q.contains("cl") { return n / 100.0 }
        if q.contains("l") { return n }              // liters ≈ kg
        if q.contains("oz") { return n * 0.02835 }
        if q.contains("lb") { return n * 0.4536 }
        return nil
    }

    // Small in-memory cache so a repeated scan of the same bottle in a demo
    // doesn't slam OFF and re-trigger 429 throttling.
    private static var cache: [String: FoodItem] = [:]

    static func fetchFoodItem(barcode: String) async throws -> FoodItem {
        if let cached = cache[barcode] {
            ScanLog.step(3, "OFF cache HIT for barcode=\(barcode) — skipping HTTP")
            return cached
        }
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            throw OFFError.notFound
        }
        var request = URLRequest(url: url)
        request.setValue("Clens/0.1 (datahacks2026; contact=team@clens.app)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        ScanLog.step(3, "OFF GET \(url.absoluteString)")

        var (data, response) = try await URLSession.shared.data(for: request)
        var statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        ScanLog.step(4, "OFF response status=\(statusCode) bytes=\(data.count)")

        // OFF throttles aggressive polling. One retry after a short back-off
        // usually gets through during a demo.
        if statusCode == 429 {
            ScanLog.step(4, "OFF 429 — retrying after 1.5s back-off")
            try await Task.sleep(nanoseconds: 1_500_000_000)
            (data, response) = try await URLSession.shared.data(for: request)
            statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            ScanLog.step(4, "OFF retry response status=\(statusCode) bytes=\(data.count)")
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OFFError.network(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
        guard decoded.status == 1, let product = decoded.product else {
            ScanLog.step(5, "OFF status != 1 — barcode not found in database")
            throw OFFError.notFound
        }
        ScanLog.step(5, "OFF JSON decoded: name='\(product.product_name ?? "?")' brands='\(product.brands ?? "?")' categories_tags=\(product.categories_tags?.count ?? 0) packaging_tags=\(product.packaging_tags?.count ?? 0) labels_tags=\(product.labels_tags?.count ?? 0) packagings=\(product.packagings?.count ?? 0)")

        let cat = category(for: product.categories_tags ?? [])
        ScanLog.step(6, "classified category=\(cat.rawValue)")
        let pkg = packaging(for: product.packaging_tags ?? [])
        let plasticScoreValue = plasticScore(packagings: product.packagings)
        ScanLog.step(7, "classified packaging=\(pkg.rawValue) plastic_score=\(plasticScoreValue.map { String(format: "%.2f", $0) } ?? "nil (no packagings)")")
        let organic = isOrganic(labels: product.labels_tags ?? [])
        let co2Kg = product.ecoscore_data?.agribalyse?.co2_total
        let ef = product.ecoscore_data?.agribalyse?.ef_total
        if let c = co2Kg, let e = ef {
            ScanLog.step(8, "agribalyse found: co2_total=\(String(format: "%.2f", c))kg/kg ef_total=\(String(format: "%.2f", e))")
        } else {
            ScanLog.step(8, "agribalyse MISSING (co2=\(co2Kg.map { "\($0)" } ?? "nil") ef=\(ef.map { "\($0)" } ?? "nil")) → will use category baseline")
        }
        ScanLog.step(9, "label signals: organic=\(organic) local=false")
        let ingredients = (product.ingredients_text ?? "")
            .split(whereSeparator: { ",;()[]".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(5)

        var item = OceanScoreEngine.foodItem(
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
        item.agribalyseCO2Kg = co2Kg
        item.agribalyseEF = ef
        item.plasticScore = plasticScoreValue
        item.imageFrontURL = product.image_front_url
        item.sizeKg = sizeKg(productQuantity: product.product_quantity, quantity: product.quantity)
        ScanLog.step(9, "size: product_quantity='\(product.product_quantity ?? "nil")' quantity='\(product.quantity ?? "nil")' → sizeKg=\(item.sizeKg.map { String(format: "%.3f", $0) } ?? "nil")")
        cache[barcode] = item
        return item
    }
}
