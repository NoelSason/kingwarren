import Foundation

// Second LLM call after the receipt has been parsed + scored. Given the items
// the user actually bought (with their current ocean scores), Claude picks
// two of the weakest and proposes a healthier / lower-impact alternative for
// each. For the alternative it returns the same shape of env priors the
// receipt scan returns, so we can push it through OceanScoreEngine and get
// a real delta_score / delta_points instead of a hand-picked number.
enum SwapSuggestionClient {

    enum SwapError: Error {
        case missingAPIKey
        case network(Int)
        case decoding
        case empty
    }

    // Input row: one item from the parsed receipt, already scored.
    struct InputItem {
        let rawText: String
        let normalizedName: String
        let category: FoodCategory
        let score: Int
    }

    // Output row: one alternative the LLM is proposing for a specific input
    // item. fromRawText references an item from InputItem so the coordinator
    // can look up the original score / FoodItem on device.
    struct Suggestion {
        let fromRawText: String
        let fromNormalizedName: String
        let toNormalizedName: String
        let toCategory: FoodCategory
        let toIsOrganic: Bool
        let toIsLocal: Bool
        let toPackagingType: PackagingType
        let toCo2TotalKg: Double?
        let toEfTotal: Double?
        let toPlasticScore: Double?     // 0-1, higher = better (already inverted)
        let toWaterLitersPerKg: Int?
        let rationale: String
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
    You are a grocery swap suggestion assistant for an ocean health app. \
    Given a list of items a user just bought and each item's ocean score \
    (0-100, higher is better), recommend healthier, lower-impact swaps for \
    exactly two items. Return ONLY valid JSON.
    """

    private static func buildUserPrompt(items: [InputItem]) -> String {
        let cats = FoodCategory.allCases.map { $0.rawValue }.joined(separator: ", ")
        let itemLines = items.map { item in
            "  - raw_text: \"\(item.rawText)\", normalized_name: \"\(item.normalizedName)\", category: \(item.category.rawValue), score: \(item.score)"
        }.joined(separator: "\n")

        return """
        The user just bought these items:

        \(itemLines)

        Pick the TWO items that would benefit most from a swap (usually the \
        two with the lowest scores, but prefer items where a realistic \
        grocery-store alternative exists). For each of the two, propose a \
        specific, plausible supermarket alternative that is healthier and \
        has a lower ocean impact. Prefer whole-food, lower-packaging, \
        lower-runoff options.

        For each alternative estimate its environmental priors on the same \
        scale used by the rest of the app. plastic_intensity is a continuous \
        0.00-1.00 rating of packaging plastic burden (higher = worse); use \
        this rubric:

          0.00 glass bottle with metal cap
          0.05 aluminum can
          0.15 glass jar with plastic lid
          0.30 paperboard carton with plastic pouch
          0.45 aseptic carton (Tetra Pak)
          0.60 PET bottle with paper label
          0.75 rigid plastic tub/jug
          0.90 multilayer flexible pouch / chip bag
          1.00 clamshell + film / polystyrene foam

        Return a JSON object with exactly this shape:

        {
          "suggestions": [
            {
              "from_raw_text": "exact raw_text of the item you are replacing",
              "from_normalized_name": "normalized_name of the item you are replacing",
              "to_normalized_name": "lowercase descriptive name of the alternative",
              "to_category": "one of: \(cats)",
              "to_is_organic": true or false,
              "to_is_local": true or false,
              "to_packaging_type": "one of: plastic, cardboard, glass, can, mixed, unknown",
              "to_co2_total_kg": <float, kg CO2-eq per kg>,
              "to_ef_total": <float, 0.0-1.5>,
              "to_plastic_intensity": <float 0.00-1.00, higher = worse>,
              "to_water_l_per_kg": <int, liters per kg>,
              "rationale": "one short sentence on why this swap is better"
            }
          ]
        }

        Return exactly 2 suggestions. from_raw_text MUST match one of the \
        raw_text values in the input list verbatim. Return ONLY the JSON, \
        no markdown, no code fences, no commentary.
        """
    }

    private struct MessageResponse: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }

    private struct ExtractedSuggestion: Decodable {
        let from_raw_text: String?
        let from_normalized_name: String?
        let to_normalized_name: String?
        let to_category: String?
        let to_is_organic: Bool?
        let to_is_local: Bool?
        let to_packaging_type: String?
        let to_co2_total_kg: Double?
        let to_ef_total: Double?
        let to_plastic_intensity: Double?
        let to_water_l_per_kg: Int?
        let rationale: String?
    }

    private struct Extracted: Decodable {
        let suggestions: [ExtractedSuggestion]?
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

    static func suggest(items: [InputItem]) async throws -> [Suggestion] {
        ScanLog.llm(40, "swap suggest: items=\(items.count)")
        guard let key = apiKey else {
            ScanLog.llm(40, "ABORT: ANTHROPIC_API_KEY missing")
            throw SwapError.missingAPIKey
        }
        guard items.count >= 2 else {
            ScanLog.llm(40, "only \(items.count) items — skipping swap call")
            return []
        }

        // Haiku is fast + cheap and the task is small — a text-only JSON
        // transformation. Matches LabelScanClient.estimateEnvironmental's
        // choice for the same reason.
        let model = "claude-haiku-4-5"
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [[
                "role": "user",
                "content": [[
                    "type": "text",
                    "text": buildUserPrompt(items: items)
                ]]
            ]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 25
        ScanLog.llm(41, "POST swap suggest model=\(model)")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        ScanLog.llm(42, "Anthropic response status=\(statusCode) bytes=\(data.count)")
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let bodySnippet = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            ScanLog.llm(42, "Anthropic error body: \(bodySnippet)")
            throw SwapError.network(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
        guard let raw = decoded.content.first(where: { $0.type == "text" })?.text, !raw.isEmpty else {
            ScanLog.llm(43, "LLM returned empty text content")
            throw SwapError.empty
        }
        let json = stripCodeFences(raw)
        guard let jsonData = json.data(using: .utf8) else {
            ScanLog.llm(43, "failed to convert stripped text to UTF-8 JSON")
            throw SwapError.decoding
        }
        let extracted = try JSONDecoder().decode(Extracted.self, from: jsonData)
        let rawSuggestions = extracted.suggestions ?? []
        ScanLog.llm(44, "LLM parsed: suggestions=\(rawSuggestions.count)")

        let suggestions: [Suggestion] = rawSuggestions.compactMap { s in
            guard let fromRaw = s.from_raw_text, let toName = s.to_normalized_name else { return nil }
            let cat = FoodCategory(rawLoose: s.to_category ?? "unknown")
            let pack = PackagingType(rawLoose: s.to_packaging_type ?? "unknown")
            let plasticScore: Double? = s.to_plastic_intensity.map { 1.0 - max(0.0, min(1.0, $0)) }
            return Suggestion(
                fromRawText: fromRaw,
                fromNormalizedName: s.from_normalized_name ?? fromRaw,
                toNormalizedName: toName,
                toCategory: cat,
                toIsOrganic: s.to_is_organic ?? false,
                toIsLocal: s.to_is_local ?? false,
                toPackagingType: pack,
                toCo2TotalKg: s.to_co2_total_kg,
                toEfTotal: s.to_ef_total,
                toPlasticScore: plasticScore,
                toWaterLitersPerKg: s.to_water_l_per_kg,
                rationale: s.rationale ?? ""
            )
        }
        ScanLog.llm(45, "built \(suggestions.count) Suggestion(s)")
        return suggestions
    }
}
