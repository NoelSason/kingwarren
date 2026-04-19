import Foundation
@preconcurrency import Vision
import CoreImage

// On-device receipt OCR. Uses Apple's VNRecognizeTextRequest so it works
// without any backend. Output shape matches what Aarav's backend is
// expected to produce, so the receipt screen is the same whether we're
// running local or remote.
enum ReceiptOCRService {

    enum OCRError: Error {
        case noImage
        case requestFailed(Error)
        case empty
    }

    struct ParsedLine {
        let rawName: String
        let price: Double
        let category: FoodCategory
    }

    struct ParsedReceipt {
        let store: String
        let dateText: String
        let total: Double
        let lines: [ParsedLine]
    }

    // Public entry: JPEG/PNG Data -> ParsedReceipt.
    static func recognize(imageData: Data) async throws -> ParsedReceipt {
        guard let image = CIImage(data: imageData) else { throw OCRError.noImage }
        let lines = try await runTextRequest(on: image)
        return parse(lines: lines)
    }

    private static func runTextRequest(on image: CIImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, err in
                if let err = err { continuation.resume(throwing: OCRError.requestFailed(err)); return }
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let strings = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: strings)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { continuation.resume(throwing: OCRError.requestFailed(error)) }
            }
        }
    }

    // MARK: - Parsing

    // Matches "ITEM NAME ... $12.34" or "ITEM NAME ... 12.34" anywhere on a line.
    private static let priceRegex = try! NSRegularExpression(
        pattern: #"([A-Z0-9][A-Z0-9 \./&\-]{2,})\s+\$?(\d{1,3}\.\d{2})"#,
        options: []
    )

    private static let totalRegex = try! NSRegularExpression(
        pattern: #"(?i)\b(total|amount due|balance)\b[^\d]*(\d{1,4}\.\d{2})"#
    )

    // Simple category heuristic on tokens found in receipt abbreviations.
    // Maps common grocery abbreviations like "GRND BF" -> beef.
    private static let categoryTokens: [(token: String, category: FoodCategory)] = [
        ("BF", .beef), ("BEEF", .beef), ("STEAK", .beef),
        ("CHKN", .poultry), ("CHICK", .poultry), ("TURK", .poultry),
        ("SLMN", .seafood), ("SALMON", .seafood), ("TUNA", .seafood), ("SHRMP", .seafood), ("FISH", .seafood),
        ("MILK", .dairy), ("CHS", .dairy), ("CHEESE", .dairy), ("YGRT", .dairy), ("YOGURT", .dairy), ("BTR", .dairy), ("BUTTER", .dairy),
        ("AVO", .fruit), ("APPL", .fruit), ("BANANA", .fruit), ("BNA", .fruit), ("ORG", .fruit),
        ("LETT", .vegetables), ("BROC", .vegetables), ("CARR", .vegetables), ("ONION", .vegetables), ("POTATO", .vegetables), ("TOMATO", .vegetables), ("SPIN", .vegetables),
        ("LENT", .legumes), ("BEAN", .legumes), ("CHKPEA", .legumes), ("TOFU", .legumes),
        ("OAT", .grains), ("RICE", .grains), ("BREAD", .grains), ("PASTA", .grains), ("FLOUR", .grains),
        ("CHIPS", .packagedSnacks), ("COOKIE", .packagedSnacks), ("CRKR", .packagedSnacks), ("CANDY", .packagedSnacks),
        ("SODA", .beverages), ("WATER", .beverages), ("COKE", .beverages), ("MONSTER", .beverages), ("REDBULL", .beverages),
        ("SOAP", .household), ("DETERG", .household), ("PAPER", .household)
    ]

    private static func category(for name: String) -> FoodCategory {
        let upper = name.uppercased()
        for (token, cat) in categoryTokens where upper.contains(token) {
            return cat
        }
        return .unknown
    }

    // Heuristic: treat "ORG ..." prefix/occurrence as an organic signal in receipts.
    static func isOrganic(_ name: String) -> Bool {
        let upper = name.uppercased()
        return upper.hasPrefix("ORG ") || upper.contains(" ORG ") || upper.contains("ORGANIC")
    }

    static func parse(lines: [String]) -> ParsedReceipt {
        var store = ""
        var dateText = ""
        var total = 0.0
        var items: [ParsedLine] = []

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if store.isEmpty, looksLikeStore(line) { store = line; continue }
            if dateText.isEmpty, looksLikeDate(line) { dateText = line; continue }

            let range = NSRange(line.startIndex..., in: line)
            if let totalMatch = totalRegex.firstMatch(in: line, range: range),
               let totalRange = Range(totalMatch.range(at: 2), in: line),
               let parsed = Double(line[totalRange]) {
                total = max(total, parsed)
                continue
            }
            if let match = priceRegex.firstMatch(in: line, range: range),
               let nameRange = Range(match.range(at: 1), in: line),
               let priceRange = Range(match.range(at: 2), in: line),
               let price = Double(line[priceRange]) {
                let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
                // Skip summary lines that coincidentally match the regex.
                let upper = name.uppercased()
                if upper == "TOTAL" || upper == "SUBTOTAL" || upper == "TAX" { continue }
                items.append(ParsedLine(rawName: name, price: price, category: category(for: name)))
            }
        }

        if total == 0, !items.isEmpty {
            total = items.reduce(0) { $0 + $1.price }
        }

        return ParsedReceipt(
            store: store.isEmpty ? "Scanned receipt" : store,
            dateText: dateText.isEmpty ? currentDateString() : dateText,
            total: total,
            lines: items
        )
    }

    private static func looksLikeStore(_ line: String) -> Bool {
        // Receipts typically put the store name at the top in ALL-CAPS.
        guard line.count >= 6, line.count <= 40 else { return false }
        let letters = line.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        let upper = letters.filter { $0.isUppercase }.count
        return Double(upper) / Double(letters.count) > 0.7 && line.rangeOfCharacter(from: .decimalDigits) == nil
    }

    private static func looksLikeDate(_ line: String) -> Bool {
        let pattern = try! NSRegularExpression(pattern: #"\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}-\d{2}-\d{2})\b"#)
        return pattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
    }

    private static func currentDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy · h:mm a"
        return f.string(from: .now)
    }
}
