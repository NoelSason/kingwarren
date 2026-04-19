import Foundation

// Swift equivalent of scan_label_image() in project_oceanscore.py.
// POSTs a captured label image (JPEG) to Anthropic's Messages API with the
// same system/user prompt and returns a FoodItem.
//
// Reads the API key from Info.plist key ANTHROPIC_API_KEY so the key never
// has to land in source. If it's missing the client throws .missingAPIKey
// and callers (ScanCoordinator) fall back to the OpenFoodFacts path or a
// category-unknown FoodItem so the demo still progresses.
enum LabelScanClient {

    enum LabelError: Error {
        case missingAPIKey
        case network(Int)
        case decoding
        case empty
    }

    // Cell 8 llm_estimate() output — used when OFF returns a product but
    // Agribalyse lifecycle data / packagings data is missing.
    struct EnvEstimate {
        let co2TotalKg: Double
        let efTotal: Double
        let plasticScore: Double     // 0.0 (heavy non-recyclable plastic) → 1.0 (no plastic)
        let waterLitersPerKg: Int
        let estimatedEcoscore: Int?
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
    You are a food label analysis assistant for an ocean health app. \
    Extract product information from the label image and return ONLY valid JSON \
    with no markdown or extra text.
    """

    private static let userPrompt: String = {
        let cats = FoodCategory.allCases.map { $0.rawValue }.joined(separator: ", ")
        return """
        Analyze this food label image and return a JSON object with exactly these fields:

        {
          "normalized_name": "lowercase descriptive product name (e.g. 'organic whole milk', 'ground beef 80/20')",
          "brand": "brand or manufacturer name, empty string if not visible",
          "category": "one of: \(cats)",
          "classification_confidence": 0.0 to 1.0 float representing how certain you are of the category,
          "is_organic": true or false (true only if label explicitly claims USDA Organic or certified organic),
          "is_local": true or false (true if label says local, regional, or names a specific nearby state/county),
          "packaging_type": "one of: plastic, cardboard, glass, can, mixed, unknown",
          "key_ingredients": ["top 3 to 5 ingredients from the ingredients list"],
          "raw_label_text": "any brand name, product name, or certifications you can read verbatim"
        }

        Be conservative with classification_confidence — use values below 0.7 if the label is unclear or the category is ambiguous.
        """
    }()

    private struct MessageResponse: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }

    private struct Extracted: Decodable {
        let normalized_name: String?
        let brand: String?
        let category: String?
        let classification_confidence: Double?
        let is_organic: Bool?
        let is_local: Bool?
        let packaging_type: String?
        let key_ingredients: [String]?
        let raw_label_text: String?
    }

    // Claude sometimes wraps JSON in ```json ... ``` even when told not to.
    // Swift's split(separator:) drops empty subsequences by default, so the
    // earlier naive approach left backticks in place when fences were the only
    // separator. This strips them directly without splitting.
    private static func stripCodeFences(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("```") else { return s }
        // Drop opening fence — either "```json\n" or "```\n" or just "```".
        if let firstNewline = s.firstIndex(of: "\n") {
            s = String(s[s.index(after: firstNewline)...])
        } else {
            s = String(s.dropFirst(3))
            if s.lowercased().hasPrefix("json") { s = String(s.dropFirst(4)) }
        }
        if s.hasSuffix("```") { s = String(s.dropLast(3)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func scan(jpegData: Data) async throws -> FoodItem {
        ScanLog.llm(1, "label scan: JPEG bytes=\(jpegData.count) (barcode path skipped)")
        guard let key = apiKey else {
            ScanLog.llm(2, "ABORT: ANTHROPIC_API_KEY missing from Info.plist / env")
            throw LabelError.missingAPIKey
        }

        let base64 = jpegData.base64EncodedString()

        let model = "claude-sonnet-4-6"
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
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
        request.timeoutInterval = 30
        ScanLog.llm(2, "POST https://api.anthropic.com/v1/messages model=\(model) image_b64=\(base64.count) chars")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        ScanLog.llm(3, "Anthropic response status=\(statusCode) bytes=\(data.count)")
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let bodySnippet = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            ScanLog.llm(3, "Anthropic error body: \(bodySnippet)")
            throw LabelError.network(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
        guard let raw = decoded.content.first(where: { $0.type == "text" })?.text, !raw.isEmpty else {
            ScanLog.llm(4, "LLM returned empty text content")
            throw LabelError.empty
        }
        ScanLog.llm(4, "LLM text block: \(raw.count) chars")

        // Strip markdown fences the same way the Python does.
        let json = stripCodeFences(raw)

        guard let jsonData = json.data(using: .utf8) else {
            ScanLog.llm(5, "failed to convert stripped text to UTF-8 JSON")
            throw LabelError.decoding
        }
        let extracted = try JSONDecoder().decode(Extracted.self, from: jsonData)
        ScanLog.llm(5, "LLM JSON parsed: name='\(extracted.normalized_name ?? "?")' category='\(extracted.category ?? "?")' organic=\(extracted.is_organic ?? false) packaging='\(extracted.packaging_type ?? "?")' confidence=\(extracted.classification_confidence ?? 0)")

        let category = FoodCategory(rawLoose: extracted.category ?? "unknown")
        let packaging = PackagingType(rawLoose: extracted.packaging_type ?? "unknown")
        let organic = extracted.is_organic ?? false
        let local = extracted.is_local ?? false
        ScanLog.llm(6, "FoodItem built from LLM (no agribalyse — will use category baseline in scoring)")

        return OceanScoreEngine.foodItem(
            name: extracted.normalized_name ?? "unknown product",
            brand: extracted.brand ?? "",
            category: category,
            barcode: nil,
            isOrganic: organic,
            isLocal: local,
            packaging: packaging,
            classificationConfidence: extracted.classification_confidence ?? 0.5,
            keyIngredients: extracted.key_ingredients ?? []
        )
    }

    // Cell 8 llm_estimate() from project_oceanscore.py — used when OFF returns
    // a product but Agribalyse lifecycle data or packagings info is missing.
    // Claude estimates co2_total_kg, ef_total, plastic_score (0-1), and
    // water_l_per_kg from the product name (and front image URL if available).
    private static let envEstimatePrompt = """
    Return ONLY a JSON object, no markdown, no code fences, no commentary:
    {
      "co2_total_kg": <float, kg CO2-eq per kg, typical 0.5-50>,
      "ef_total": <float, environmental footprint 0.0-1.5, includes eutrophication>,
      "plastic_score": <float 0.0-1.0, where 0=heavy non-recyclable plastic, 1.0=no plastic>,
      "water_l_per_kg": <int, liters of freshwater per kg, typical 100-15000>,
      "estimated_ecoscore": <int 0-100, 100=best>
    }
    """

    private struct EnvEstimateJSON: Decodable {
        let co2_total_kg: Double?
        let ef_total: Double?
        let plastic_score: Double?
        let water_l_per_kg: Int?
        let estimated_ecoscore: Int?
    }

    static func estimateEnvironmental(productName: String, imageURL: String?) async throws -> EnvEstimate {
        ScanLog.llm(7, "estimate request: name='\(productName)' image=\(imageURL ?? "none")")
        guard let key = apiKey else {
            ScanLog.llm(7, "ABORT: ANTHROPIC_API_KEY missing")
            throw LabelError.missingAPIKey
        }

        let textBlock: [String: Any] = [
            "type": "text",
            "text": "Estimate environmental impact for this food product: \"\(productName)\"\n\n\(envEstimatePrompt)"
        ]
        var content: [[String: Any]] = []
        // Download the OFF image ourselves and send as base64. Passing the URL
        // directly makes Anthropic's fetcher download it, and images.openfoodfacts.org
        // is slow enough that that path 400s with "timed out while trying to
        // download the file" — observed in production.
        if let imageURL, let url = URL(string: imageURL) {
            do {
                var imgReq = URLRequest(url: url)
                imgReq.timeoutInterval = 8
                let (imgData, imgResp) = try await URLSession.shared.data(for: imgReq)
                let imgStatus = (imgResp as? HTTPURLResponse)?.statusCode ?? -1
                ScanLog.llm(7, "fetched OFF image: status=\(imgStatus) bytes=\(imgData.count)")
                if imgStatus == 200, !imgData.isEmpty {
                    content.append([
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": imgData.base64EncodedString()
                        ]
                    ])
                } else {
                    ScanLog.llm(7, "OFF image fetch non-200 — proceeding text-only")
                }
            } catch {
                ScanLog.llm(7, "OFF image fetch FAILED (\(error)) — proceeding text-only")
            }
        }
        content.append(textBlock)

        let model = "claude-haiku-4-5"
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [["role": "user", "content": content]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20
        ScanLog.llm(8, "POST https://api.anthropic.com/v1/messages model=\(model) image=\(imageURL != nil)")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        ScanLog.llm(8, "Anthropic response status=\(statusCode) bytes=\(data.count)")
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let bodySnippet = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            ScanLog.llm(8, "Anthropic error body: \(bodySnippet)")
            throw LabelError.network(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
        guard let raw = decoded.content.first(where: { $0.type == "text" })?.text, !raw.isEmpty else {
            throw LabelError.empty
        }
        let json = stripCodeFences(raw)
        ScanLog.llm(9, "LLM raw text (\(raw.count) chars) → stripped (\(json.count) chars): \(json.prefix(200))")
        guard let jsonData = json.data(using: .utf8) else { throw LabelError.decoding }
        let parsed = try JSONDecoder().decode(EnvEstimateJSON.self, from: jsonData)

        let est = EnvEstimate(
            co2TotalKg: parsed.co2_total_kg ?? 5.0,
            efTotal: parsed.ef_total ?? 0.5,
            plasticScore: max(0.0, min(1.0, parsed.plastic_score ?? 0.5)),
            waterLitersPerKg: parsed.water_l_per_kg ?? 2000,
            estimatedEcoscore: parsed.estimated_ecoscore
        )
        ScanLog.llm(9, String(format: "estimate parsed: co2=%.2f ef=%.2f plastic_score=%.2f water_L=%d ecoscore=%@",
                              est.co2TotalKg, est.efTotal,
                              est.plasticScore, est.waterLitersPerKg,
                              est.estimatedEcoscore.map { "\($0)" } ?? "nil"))
        return est
    }
}
