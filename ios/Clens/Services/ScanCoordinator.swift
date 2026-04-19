import Foundation
import Combine

// Uniformly-formatted debug log lines so you can follow a single scan
// end-to-end in the Xcode console. Filter with: "[SCAN"
enum ScanLog {
    static func step(_ n: Int, _ message: String) {
        print("[SCAN \(String(format: "%02d", n))] \(message)")
    }
    static func llm(_ n: Int, _ message: String) {
        print("[SCAN L\(n)] \(message)")
    }
}

// Orchestrator between camera capture, scoring, and the result views.
// Holds the most recent live-scan result so ScanResultView / ReceiptResultView
// can render live data instead of the Mock fallback when available.
@MainActor
final class ScanCoordinator: ObservableObject {

    enum Status: Equatable {
        case idle
        case busy(String)     // message shown in UI
        case error(String)
    }

    @Published var status: Status = .idle
    @Published private(set) var liveProduct: Product? = nil
    @Published private(set) var liveReceipt: Receipt? = nil

    let ocean: OceanStressService
    let history: ScanHistoryStore?

    init(ocean: OceanStressService, history: ScanHistoryStore? = nil) {
        self.ocean = ocean
        self.history = history
    }

    // MARK: - Product flows

    func handleBarcode(_ barcode: String) async {
        ScanLog.step(2, "coordinator received barcode='\(barcode)', starting OFF lookup (stress=\(String(format: "%.2f", ocean.stressIndex)))")
        status = .busy("Looking up barcode…")
        do {
            var item = try await OpenFoodFactsClient.fetchFoodItem(barcode: barcode)
            ScanLog.step(10, "FoodItem built: name='\(item.normalizedName)' brand='\(item.brand)' category=\(item.category.rawValue) organic=\(item.isOrganic) packaging=\(item.packagingType.rawValue)")

            // Python Cell 8 skip-LLM rule: only the agribalyse + OFF-packagings
            // path avoids the LLM call. Water stays neutral (0.5) in that case.
            let hasCO2 = item.agribalyseCO2Kg != nil
            let hasPlastic = item.plasticScore != nil
            if hasCO2 && hasPlastic {
                item.waterLitersPerKg = 2000
                item.waterScore = 0.5
                ScanLog.step(11, "agribalyse+packagings complete — skipping LLM, water neutral (0.5)")
            } else if LabelScanClient.isConfigured {
                ScanLog.step(11, "missing \(hasCO2 ? "" : "co2/ef ")\(hasPlastic ? "" : "plastic_score ")— calling LLM estimate")
                status = .busy("Estimating impact…")
                do {
                    let est = try await LabelScanClient.estimateEnvironmental(
                        productName: item.normalizedName,
                        imageURL: item.imageFrontURL
                    )
                    if item.agribalyseCO2Kg == nil { item.agribalyseCO2Kg = est.co2TotalKg }
                    if item.agribalyseEF == nil { item.agribalyseEF = est.efTotal }
                    if item.plasticScore == nil { item.plasticScore = est.plasticScore }
                    item.waterLitersPerKg = est.waterLitersPerKg
                    item.waterScore = 1.0 - min(Double(est.waterLitersPerKg) / 15000.0, 1.0)
                    ScanLog.step(11, String(format: "LLM estimate applied: plastic_score=%.2f water_L=%d water_score=%.2f",
                                            item.plasticScore ?? 0.5, item.waterLitersPerKg ?? 0, item.waterScore ?? 0.5))
                } catch {
                    ScanLog.step(11, "LLM estimate FAILED (\(error)) — falling back to category baseline")
                }
            } else {
                ScanLog.step(11, "no agribalyse data AND LLM not configured — falling back to category baseline")
            }
            let product = OceanScoreEngine.uiProduct(from: item, stressIndex: ocean.stressIndex)
            ScanLog.step(17, "product ready: id='\(product.id)' score=\(product.score) displayPoints=\(Int(Double(product.score) * 1.6)) facts=\(product.facts.count)")
            self.liveProduct = product
            self.status = .idle
            history?.log(.product(product, points: OceanScoreEngine.tierPoints(for: product.score)))
            ScanLog.step(18, "liveProduct published → ScanView will navigate to result")
        } catch {
            ScanLog.step(99, "OFF lookup failed (\(error)) — showing baseline estimate")
            // Fall back so the demo still progresses — unknown-category item
            // scored against the stress index gives a sensible-looking card.
            let fallback = FoodItem.unknown(name: "Barcode \(barcode)", barcode: barcode)
            let product = OceanScoreEngine.uiProduct(from: fallback, stressIndex: ocean.stressIndex)
            self.liveProduct = product
            self.status = .error("Couldn't reach OpenFoodFacts — showing a baseline estimate.")
        }
    }

    func handleLabelImage(_ jpeg: Data) async {
        ScanLog.step(20, "handleLabelImage: JPEG bytes=\(jpeg.count), LabelScanClient configured=\(LabelScanClient.isConfigured)")
        status = .busy("Reading label…")

        if LabelScanClient.isConfigured {
            do {
                let item = try await LabelScanClient.scan(jpegData: jpeg)
                ScanLog.step(21, "LLM path SUCCESS → FoodItem name='\(item.normalizedName)' category=\(item.category.rawValue)")
                let product = OceanScoreEngine.uiProduct(from: item, stressIndex: ocean.stressIndex)
                self.liveProduct = product
                self.status = .idle
                ScanLog.step(25, "liveProduct published via label/LLM path → ScanView will navigate")
                return
            } catch {
                ScanLog.step(22, "LLM path FAILED (\(error)) — falling back to unknown baseline")
            }
        } else {
            ScanLog.step(22, "LLM not configured (no ANTHROPIC_API_KEY) — falling back to unknown baseline")
        }

        // No API key (or network error): use an unknown-category baseline so
        // the UI still shows a meaningful score instead of failing the demo.
        let item = FoodItem.unknown(name: "Scanned label")
        ScanLog.step(23, "using FoodItem.unknown('Scanned label') — this is why climate/runoff/plastic are all 50")
        let product = OceanScoreEngine.uiProduct(from: item, stressIndex: ocean.stressIndex)
        self.liveProduct = product
        self.status = LabelScanClient.isConfigured
            ? .error("Couldn't reach the label service.")
            : .idle
        ScanLog.step(25, "liveProduct published via fallback path → ScanView will navigate")
    }

    // MARK: - Receipt flow

    func handleReceiptImage(_ jpeg: Data) async {
        ScanLog.step(30, "handleReceiptImage: JPEG bytes=\(jpeg.count) → starting OCR")
        status = .busy("Reading receipt…")
        do {
            let parsed = try await ReceiptOCRService.recognize(imageData: jpeg)
            ScanLog.step(31, "receipt OCR parsed: store='\(parsed.store)' total=\(parsed.total) lines=\(parsed.lines.count)")
            let receipt = buildReceipt(from: parsed)
            ScanLog.step(33, "receipt built: items=\(receipt.items.count) earned=\(receipt.earned) avgScore=\(receipt.averageScore)")
            self.liveReceipt = receipt
            self.status = .idle
            history?.log(.receipt(receipt))
        } catch {
            ScanLog.step(30, "receipt OCR FAILED: \(error)")
            self.status = .error("Couldn't read receipt. Try a clearer photo.")
        }
    }

    private func buildReceipt(from parsed: ReceiptOCRService.ParsedReceipt) -> Receipt {
        let stress = ocean.stressIndex

        var items: [ReceiptItem] = []
        var totalEarned: Int = 0
        var totalScore: Int = 0

        for (idx, line) in parsed.lines.enumerated() {
            ScanLog.step(32, "receipt line \(idx+1)/\(parsed.lines.count): '\(line.rawName)' category=\(line.category.rawValue) price=\(line.price)")
            let organic = ReceiptOCRService.isOrganic(line.rawName)
            let item = OceanScoreEngine.foodItem(
                name: line.rawName,
                brand: "",
                category: line.category,
                barcode: nil,
                isOrganic: organic,
                isLocal: false,
                packaging: .unknown,
                classificationConfidence: line.category == .unknown ? 0.3 : 0.7
            )
            let scored = OceanScoreEngine.score(item, stressIndex: stress)
            totalEarned += scored.displayPoints
            totalScore += scored.score

            // Use a stable pid per line so ScanResultView can look it up.
            let pid = slug(line.rawName)
            // Stash the product so the detail screen can find it.
            parsedCache[pid] = OceanScoreEngine.uiProduct(from: item, stressIndex: stress)

            items.append(ReceiptItem(name: line.rawName.capitalized, price: line.price, pid: pid))
        }

        let avgScore = items.isEmpty ? 0 : totalScore / items.count

        return Receipt(
            store: parsed.store,
            date: parsed.dateText,
            total: parsed.total,
            items: items,
            earned: totalEarned,
            averageScore: avgScore
        )
    }

    // In-memory store for products discovered during receipt OCR so
    // ScanResultView can render them when the user taps a line item.
    private var parsedCache: [String: Product] = [:]

    func product(for pid: String) -> Product? {
        if let live = liveProduct, live.id == pid { return live }
        return parsedCache[pid]
    }

    private func slug(_ s: String) -> String {
        let lower = s.lowercased()
        let stripped = lower.filter { $0.isLetter || $0.isNumber || $0 == " " }
        let hyphenated = stripped.replacingOccurrences(of: " ", with: "-")
        return hyphenated.isEmpty ? UUID().uuidString : hyphenated
    }

    // Called when the user enters the scan view so stale state doesn't
    // linger between different scan sessions.
    func reset() {
        liveProduct = nil
        liveReceipt = nil
        status = .idle
    }
}
