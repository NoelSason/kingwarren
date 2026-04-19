import Foundation

// Single Claude vision call on a receipt JPEG. Returns the store header plus
// per-item rows with category, label signals, and the same environmental
// priors (co2_total_kg, ef_total, plastic_intensity, water_l_per_kg) that
// LabelScanClient.estimateEnvironmental produces for single labels — so
// receipt scoring and barcode scoring feed the same OceanScoreEngine inputs.
enum ReceiptScanClient {

    enum ReceiptError: Error {
        case missingAPIKey
        case network(Int)
        case decoding
        case empty
    }

    struct ParsedItem {
        let rawText: String
        let normalizedName: String
        let category: FoodCategory
        let classificationConfidence: Double
        let isOrganic: Bool
        let isLocal: Bool
        let packagingType: PackagingType
        let price: Double
        let co2TotalKg: Double?
        let efTotal: Double?
        let plasticScore: Double?        // 0-1, higher = less plastic = better
        let waterLitersPerKg: Int?
    }

    struct ParsedReceipt {
        let store: String
        let dateText: String
        let total: Double
        let items: [ParsedItem]
    }

    private static var apiKey: String? {
        if let key = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String,
           !key.isEmpty { return key }
        if let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !env.isEmpty {
            return env
        }
        return nil
    }

    static var isConfigured: Bool { apiKey != nil }

    private static let systemPrompt = """
    You are a grocery receipt analysis assistant for an ocean health app. \
    Extract every purchased line item from the receipt image and return ONLY \
    valid JSON with no markdown or extra text.
    """

    private static let userPrompt: String = {
        let cats = FoodCategory.allCases.map { $0.rawValue }.joined(separator: ", ")
        return """
        Read this grocery receipt image. Extract the store name, date (if visible), \
        the receipt total, and every purchased line item. Skip summary rows like \
        subtotal, tax, total, change, tender, coupon, and loyalty lines.

        Expand common grocery abbreviations when producing normalized_name:
          GRND BF 80/20 -> ground beef 80/20
          ORG BNNS      -> organic bananas
          WHL MLK       -> whole milk
          CHKN BRST     -> chicken breast
          YGRT          -> yogurt

        For every item, estimate environmental priors on the same scale used \
        for individual product labels. plastic_intensity is a continuous \
        0.00-1.00 rating of how much of the product's total packaging mass is \
        plastic, weighted by how hard that plastic is to recycle. HIGHER = \
        MORE PLASTIC = WORSE. Do NOT snap to 0.0, 0.3, or 1.0 — pick a value \
        that reflects the actual packaging.

        Rubric (calibrate against these):
          0.00  glass bottle with metal cap, no plastic at all
          0.05  aluminum can, only trace plastic liner
          0.15  glass jar with plastic lid, or cardboard box with small plastic window
          0.30  paperboard carton with plastic inner pouch, or mostly-cardboard multipack
          0.45  aseptic carton (Tetra Pak) — layered paper/plastic/foil
          0.60  PET bottle with paper label (e.g. most bottled water, soda)
          0.75  thick rigid plastic tub/jug, or PET bottle with plastic sleeve
          0.90  multilayer flexible plastic pouch / chip bag / snack wrapper
          1.00  heavy non-recyclable plastic, clamshell + film, or polystyrene foam

        Return a JSON object with exactly this shape:

        {
          "store": "store name as printed on receipt, empty string if unreadable",
          "date_text": "date as printed (MM/DD/YYYY or similar), empty string if none",
          "total": <float, receipt total in dollars, 0 if unreadable>,
          "items": [
            {
              "raw_text": "exact line text as printed (short)",
              "normalized_name": "lowercase expanded descriptive name (e.g. 'ground beef 80/20')",
              "category": "one of: \(cats)",
              "classification_confidence": 0.0 to 1.0 float,
              "is_organic": true or false,
              "is_local": true or false,
              "packaging_type": "one of: plastic, cardboard, glass, can, mixed, unknown",
              "price": <float, line price in dollars, 0 if unknown>,
              "co2_total_kg": <float, kg CO2-eq per kg, typical 0.5-50>,
              "ef_total": <float, environmental footprint 0.0-1.5>,
              "plastic_intensity": <float 0.00-1.00, higher = worse, see rubric>,
              "water_l_per_kg": <int, liters freshwater per kg, typical 100-15000>
            }
          ]
        }

        Be conservative with classification_confidence — use values below 0.7 \
        if the line is ambiguous or abbreviations are unusual. Return ONLY the \
        JSON object, no markdown, no code fences, no commentary.
        """
    }()

    private struct MessageResponse: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }

    private struct ExtractedItem: Decodable {
        let raw_text: String?
        let normalized_name: String?
        let category: String?
        let classification_confidence: Double?
        let is_organic: Bool?
        let is_local: Bool?
        let packaging_type: String?
        let price: Double?
        let co2_total_kg: Double?
        let ef_total: Double?
        let plastic_intensity: Double?
        let water_l_per_kg: Int?
    }

    private struct Extracted: Decodable {
        let store: String?
        let date_text: String?
        let total: Double?
        let items: [ExtractedItem]?
    }

    private static func stripCodeFences(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("```") else { return s }
        if let firstNewline = s.firstIndex(of: "\n") {
            s = String(s[s.index(after: firstNewline)...])
        } else {
            s = String(s.dropFirst(3))
            if s.lowercased().hasPrefix("json") { s = String(s.dropFirst(4)) }
        }
        if s.hasSuffix("```") { s = String(s.dropLast(3)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func scan(jpegData: Data) async throws -> ParsedReceipt {
        ScanLog.llm(30, "receipt scan: JPEG bytes=\(jpegData.count) (single LLM call)")
        guard let key = apiKey else {
            ScanLog.llm(30, "ABORT: ANTHROPIC_API_KEY missing")
            throw ReceiptError.missingAPIKey
        }

        let base64 = jpegData.base64EncodedString()

        let model = "claude-sonnet-4-6"
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64
                        ]
                    ],
                    [
                        "type": "text",
                        "text": userPrompt
                    ]
                ]
            ]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 45
        ScanLog.llm(31, "POST receipt scan model=\(model) image_b64=\(base64.count) chars")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        ScanLog.llm(32, "Anthropic response status=\(statusCode) bytes=\(data.count)")
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let bodySnippet = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            ScanLog.llm(32, "Anthropic error body: \(bodySnippet)")
            throw ReceiptError.network(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
        guard let raw = decoded.content.first(where: { $0.type == "text" })?.text, !raw.isEmpty else {
            ScanLog.llm(33, "LLM returned empty text content")
            throw ReceiptError.empty
        }
        ScanLog.llm(33, "LLM text block: \(raw.count) chars")

        let json = stripCodeFences(raw)
        guard let jsonData = json.data(using: .utf8) else {
            ScanLog.llm(34, "failed to convert stripped text to UTF-8 JSON")
            throw ReceiptError.decoding
        }
        let extracted = try JSONDecoder().decode(Extracted.self, from: jsonData)
        let rawItems = extracted.items ?? []
        ScanLog.llm(34, "LLM JSON parsed: store='\(extracted.store ?? "?")' total=\(extracted.total ?? 0) items=\(rawItems.count)")

        let items: [ParsedItem] = rawItems.map { e in
            let rawText = e.raw_text ?? (e.normalized_name ?? "item")
            let name = e.normalized_name ?? rawText
            let cat = FoodCategory(rawLoose: e.category ?? "unknown")
            let pack = PackagingType(rawLoose: e.packaging_type ?? "unknown")
            // plastic_intensity (0-1, higher = worse) → plasticScore (higher = better)
            let plasticScore: Double? = e.plastic_intensity.map { 1.0 - max(0.0, min(1.0, $0)) }
            return ParsedItem(
                rawText: rawText,
                normalizedName: name,
                category: cat,
                classificationConfidence: e.classification_confidence ?? (cat == .unknown ? 0.3 : 0.7),
                isOrganic: e.is_organic ?? false,
                isLocal: e.is_local ?? false,
                packagingType: pack,
                price: e.price ?? 0.0,
                co2TotalKg: e.co2_total_kg,
                efTotal: e.ef_total,
                plasticScore: plasticScore,
                waterLitersPerKg: e.water_l_per_kg
            )
        }

        let store = (extracted.store?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? "Scanned receipt"
        let dateText = (extracted.date_text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? currentDateString()
        let total = (extracted.total ?? 0) > 0
            ? (extracted.total ?? 0)
            : items.reduce(0) { $0 + $1.price }

        ScanLog.llm(35, "ParsedReceipt built: store='\(store)' items=\(items.count) total=\(total)")
        return ParsedReceipt(store: store, dateText: dateText, total: total, items: items)
    }

    private static func currentDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy · h:mm a"
        return f.string(from: .now)
    }
}
