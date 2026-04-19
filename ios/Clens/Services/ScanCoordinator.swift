import Foundation
import Combine

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
        status = .busy("Looking up barcode…")
        do {
            let item = try await OpenFoodFactsClient.fetchFoodItem(barcode: barcode)
            let product = OceanScoreEngine.uiProduct(from: item, stressIndex: ocean.stressIndex)
            self.liveProduct = product
            self.status = .idle
            history?.log(.product(product, points: OceanScoreEngine.tierPoints(for: product.score)))
        } catch {
            // Fall back so the demo still progresses — unknown-category item
            // scored against the stress index gives a sensible-looking card.
            let fallback = FoodItem.unknown(name: "Barcode \(barcode)", barcode: barcode)
            let product = OceanScoreEngine.uiProduct(from: fallback, stressIndex: ocean.stressIndex)
            self.liveProduct = product
            self.status = .error("Couldn't reach OpenFoodFacts — showing a baseline estimate.")
        }
    }

    func handleLabelImage(_ jpeg: Data) async {
        status = .busy("Reading label…")

        if LabelScanClient.isConfigured {
            do {
                let item = try await LabelScanClient.scan(jpegData: jpeg)
                let product = OceanScoreEngine.uiProduct(from: item, stressIndex: ocean.stressIndex)
                self.liveProduct = product
                self.status = .idle
                return
            } catch {
                // Fall through to local fallback.
            }
        }

        // No API key (or network error): use an unknown-category baseline so
        // the UI still shows a meaningful score instead of failing the demo.
        let item = FoodItem.unknown(name: "Scanned label")
        let product = OceanScoreEngine.uiProduct(from: item, stressIndex: ocean.stressIndex)
        self.liveProduct = product
        self.status = LabelScanClient.isConfigured
            ? .error("Couldn't reach the label service.")
            : .idle
    }

    // MARK: - Receipt flow

    func handleReceiptImage(_ jpeg: Data) async {
        status = .busy("Reading receipt…")
        do {
            let parsed = try await ReceiptOCRService.recognize(imageData: jpeg)
            let receipt = buildReceipt(from: parsed)
            self.liveReceipt = receipt
            self.status = .idle
            history?.log(.receipt(receipt))
        } catch {
            self.status = .error("Couldn't read receipt. Try a clearer photo.")
        }
    }

    private func buildReceipt(from parsed: ReceiptOCRService.ParsedReceipt) -> Receipt {
        let stress = ocean.stressIndex

        var items: [ReceiptItem] = []
        var totalEarned: Int = 0
        var totalScore: Int = 0

        for line in parsed.lines {
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
