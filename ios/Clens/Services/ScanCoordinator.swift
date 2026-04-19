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

    // Set by ClensApp once a session exists so the receipt flow can persist
    // scans to Supabase and update the in-memory balance in ProfileService.
    weak var profileService: ProfileService?
    var session: AuthSession?

    init(ocean: OceanStressService, history: ScanHistoryStore? = nil) {
        self.ocean = ocean
        self.history = history
    }

    // MARK: - Product flows

    // OFF returned a response but it's useless for scoring — no category, no
    // brand, no lifecycle data. Worth silently falling back to an image + LLM
    // identification instead of showing an "Unknown brand" card.
    private func isUnusableOFFResult(_ item: FoodItem) -> Bool {
        item.category == .unknown
            && item.brand.isEmpty
            && item.agribalyseCO2Kg == nil
    }

    // Apply an LLM EnvEstimate to a FoodItem, only filling fields that are
    // currently nil and only where the LLM actually returned a value. Never
    // overwrites true OFF data, never hardcodes defaults.
    private func applyEnvEstimate(_ est: LabelScanClient.EnvEstimate, to item: inout FoodItem) {
        if item.agribalyseCO2Kg == nil, let v = est.co2TotalKg      { item.agribalyseCO2Kg = v }
        if item.agribalyseEF    == nil, let v = est.efTotal         { item.agribalyseEF    = v }
        if item.plasticScore    == nil, let v = est.plasticScore    { item.plasticScore    = v }
        if item.waterScore      == nil, let v = est.waterLitersPerKg {
            item.waterLitersPerKg = v
            item.waterScore = 1.0 - min(Double(v) / 15000.0, 1.0)
        }
    }

    // Fill any of co2/ef/plastic/water that aren't already populated by
    // calling the Cell-8 LLM estimator. Safe to call with the LLM not
    // configured or offline; missing fields simply stay nil.
    private func fillMissingWithLLM(_ item: inout FoodItem) async {
        let hasCO2     = item.agribalyseCO2Kg != nil && item.agribalyseEF != nil
        let hasPlastic = item.plasticScore != nil
        let hasWater   = item.waterScore != nil
        let needsLLM   = !(hasCO2 && hasPlastic && hasWater)

        guard needsLLM else {
            ScanLog.step(11, "OFF returned full co2/ef/plastic/water — no LLM call needed")
            return
        }
        guard LabelScanClient.isConfigured else {
            ScanLog.step(11, "LLM not configured — leaving missing fields nil; scoring will use category baseline for those dimensions")
            return
        }
        let missing = [hasCO2 ? nil : "co2/ef", hasPlastic ? nil : "plastic", hasWater ? nil : "water"]
            .compactMap { $0 }.joined(separator: ",")
        ScanLog.step(11, "LLM needed — missing: \(missing)")
        status = .busy("Estimating impact…")
        do {
            let est = try await LabelScanClient.estimateEnvironmental(
                productName: item.normalizedName,
                imageURL: item.imageFrontURL
            )
            applyEnvEstimate(est, to: &item)
            ScanLog.step(11, String(format: "LLM estimate applied: plastic_score=%@ water_L=%@ water_score=%@",
                                    item.plasticScore.map { String(format: "%.2f", $0) } ?? "nil",
                                    item.waterLitersPerKg.map { "\($0)" } ?? "nil",
                                    item.waterScore.map { String(format: "%.2f", $0) } ?? "nil"))
        } catch {
            ScanLog.step(11, "LLM estimate FAILED (\(error)) — leaving missing fields nil; scoring will use category baseline for those dimensions")
        }
    }

    // Barcode entry point. When OFF has no useful data, the view layer gives
    // us a closure that grabs a still frame from the camera; we route that
    // through the same label-scan + env-estimate flow the product-label mode
    // uses, so the user silently gets an image-identified score instead of
    // an "Unknown brand" placeholder.
    func handleBarcode(_ barcode: String, captureFallbackPhoto: (() async throws -> Data)? = nil) async {
        ScanLog.step(2, "coordinator received barcode='\(barcode)', starting OFF lookup (stress=\(String(format: "%.2f", ocean.stressIndex)))")
        status = .busy("Looking up barcode…")

        var item: FoodItem
        var offResolved = false
        do {
            item = try await OpenFoodFactsClient.fetchFoodItem(barcode: barcode)
            ScanLog.step(10, "FoodItem built: name='\(item.normalizedName)' brand='\(item.brand)' category=\(item.category.rawValue) organic=\(item.isOrganic) packaging=\(item.packagingType.rawValue)")
            if isUnusableOFFResult(item) {
                ScanLog.step(10, "OFF returned skeleton record (unknown category + blank brand + no agribalyse) — treating as miss")
                throw OpenFoodFactsClient.OFFError.notFound
            }
            offResolved = true
        } catch {
            ScanLog.step(99, "OFF unusable (\(error)) — attempting silent image + LLM fallback")
            if let capture = captureFallbackPhoto, LabelScanClient.isConfigured {
                status = .busy("Identifying product…")
                do {
                    let jpeg = try await capture()
                    ScanLog.step(99, "fallback photo captured: JPEG bytes=\(jpeg.count) → LabelScanClient.scan")
                    var labelItem = try await LabelScanClient.scan(jpegData: jpeg)
                    // Tag the item with the barcode we originally decoded so
                    // history / dedupe still work.
                    labelItem.barcode = barcode
                    await fillMissingWithLLM(&labelItem)
                    let product = OceanScoreEngine.uiProduct(from: labelItem, stressIndex: ocean.stressIndex)
                    ScanLog.step(17, "product ready via barcode→image fallback: id='\(product.id)' score=\(product.score)")
                    self.liveProduct = product
                    self.status = .idle
                    history?.log(.product(product, points: OceanScoreEngine.tierPoints(for: product.score)))
                    ScanLog.step(18, "liveProduct published via barcode→image fallback → ScanView will navigate")
                    return
                } catch {
                    ScanLog.step(99, "barcode→image fallback FAILED (\(error)) — using baseline estimate")
                }
            } else {
                ScanLog.step(99, "no capture closure or LLM not configured — using baseline estimate")
            }
            let fallback = FoodItem.unknown(name: "Barcode \(barcode)", barcode: barcode)
            let product = OceanScoreEngine.uiProduct(from: fallback, stressIndex: ocean.stressIndex)
            self.liveProduct = product
            self.status = .error("Couldn't identify this barcode — showing a baseline estimate.")
            return
        }

        _ = offResolved
        await fillMissingWithLLM(&item)
        let product = OceanScoreEngine.uiProduct(from: item, stressIndex: ocean.stressIndex)
        ScanLog.step(17, "product ready: id='\(product.id)' score=\(product.score) displayPoints=\(Int(Double(product.score) * 1.6)) facts=\(product.facts.count)")
        self.liveProduct = product
        self.status = .idle
        history?.log(.product(product, points: OceanScoreEngine.tierPoints(for: product.score)))
        ScanLog.step(18, "liveProduct published → ScanView will navigate to result")
    }

    func handleLabelImage(_ jpeg: Data) async {
        ScanLog.step(20, "handleLabelImage: JPEG bytes=\(jpeg.count), LabelScanClient configured=\(LabelScanClient.isConfigured)")
        status = .busy("Reading label…")

        if LabelScanClient.isConfigured {
            do {
                var item = try await LabelScanClient.scan(jpegData: jpeg)
                ScanLog.step(21, "LLM path SUCCESS → FoodItem name='\(item.normalizedName)' category=\(item.category.rawValue)")
                // Label classification doesn't give per-SKU co2/ef/plastic/
                // water — fill those via the Cell-8 estimator just like the
                // barcode path does. Without this, every label scan falls
                // through to the category-baseline scoring branch.
                await fillMissingWithLLM(&item)
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
        ScanLog.step(30, "handleReceiptImage: JPEG bytes=\(jpeg.count) (LLM configured=\(ReceiptScanClient.isConfigured))")

        // Primary path: single Claude vision call → per-item env priors → score
        // via the same OceanScoreEngine the barcode flow uses. Falls through
        // to local OCR if the key is missing or the call fails.
        if ReceiptScanClient.isConfigured {
            status = .busy("Identifying items…")
            do {
                let parsed = try await ReceiptScanClient.scan(jpegData: jpeg)
                ScanLog.step(31, "LLM receipt parsed: store='\(parsed.store)' total=\(parsed.total) items=\(parsed.items.count)")
                let receipt = buildReceipt(fromLLM: parsed)
                ScanLog.step(33, "receipt built (LLM): items=\(receipt.items.count) earned=\(receipt.earned) avgScore=\(receipt.averageScore)")
                self.liveReceipt = receipt
                self.status = .idle
                history?.log(.receipt(receipt))
                await syncReceiptToSupabase(receipt)
                // Fire the swap-suggestion LLM call in the background so the
                // receipt renders immediately; we re-publish liveReceipt with
                // swaps filled in once Claude responds.
                Task { [weak self] in
                    await self?.fetchSwaps(originals: parsed.items)
                }
                return
            } catch {
                ScanLog.step(30, "LLM receipt path FAILED (\(error)) — falling back to on-device OCR")
            }
        }

        status = .busy("Reading receipt…")
        do {
            let parsed = try await ReceiptOCRService.recognize(imageData: jpeg)
            ScanLog.step(31, "receipt OCR parsed: store='\(parsed.store)' total=\(parsed.total) lines=\(parsed.lines.count)")
            let receipt = buildReceipt(from: parsed)
            ScanLog.step(33, "receipt built (OCR): items=\(receipt.items.count) earned=\(receipt.earned) avgScore=\(receipt.averageScore)")
            self.liveReceipt = receipt
            self.status = .idle
            history?.log(.receipt(receipt))
            await syncReceiptToSupabase(receipt)
        } catch {
            ScanLog.step(30, "receipt OCR FAILED: \(error)")
            self.status = .error("Couldn't read receipt. Try a clearer photo.")
        }
    }

    // Writes the scan to Supabase and bumps the signed-in user's seabucks
    // balance via the add_seabucks RPC. In-memory ProfileService.balance is
    // updated so Home / Rewards / Profile reflect the new total immediately.
    // Silent no-op if there's no session or Supabase isn't configured.
    private func syncReceiptToSupabase(_ receipt: Receipt) async {
        guard let userID = session?.userID else {
            ScanLog.step(34, "no session — skipping Supabase scan sync")
            return
        }
        do {
            let newBalance = try await ScanSyncService.sync(userID: userID, receipt: receipt)
            ScanLog.step(34, "Supabase scan sync OK: +\(receipt.earned) → new balance=\(newBalance)")
            profileService?.balance = newBalance
        } catch {
            ScanLog.step(34, "Supabase scan sync FAILED: \(error)")
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

    // LLM receipt path: each ParsedItem already carries per-SKU env priors
    // (co2/ef/plastic/water), so we build the FoodItem from the category and
    // then inline-apply those priors — matching the barcode+label flow so
    // receipt and barcode scores stay comparable.
    private func buildReceipt(fromLLM parsed: ReceiptScanClient.ParsedReceipt) -> Receipt {
        let stress = ocean.stressIndex

        var items: [ReceiptItem] = []
        var totalEarned: Int = 0
        var totalScore: Int = 0

        for (idx, p) in parsed.items.enumerated() {
            ScanLog.step(32, "LLM receipt line \(idx+1)/\(parsed.items.count): '\(p.rawText)' → '\(p.normalizedName)' category=\(p.category.rawValue) price=\(p.price)")
            var item = OceanScoreEngine.foodItem(
                name: p.normalizedName,
                brand: "",
                category: p.category,
                barcode: nil,
                isOrganic: p.isOrganic,
                isLocal: p.isLocal,
                packaging: p.packagingType,
                classificationConfidence: p.classificationConfidence
            )
            // Same prior-merge policy as ScanCoordinator.applyEnvEstimate: only
            // fill fields that are currently nil, never overwrite real data.
            if item.agribalyseCO2Kg == nil, let v = p.co2TotalKg { item.agribalyseCO2Kg = v }
            if item.agribalyseEF    == nil, let v = p.efTotal    { item.agribalyseEF    = v }
            if item.plasticScore    == nil, let v = p.plasticScore { item.plasticScore = v }
            if item.waterScore      == nil, let v = p.waterLitersPerKg {
                item.waterLitersPerKg = v
                item.waterScore = 1.0 - min(Double(v) / 15000.0, 1.0)
            }

            let scored = OceanScoreEngine.score(item, stressIndex: stress)
            totalEarned += scored.displayPoints
            totalScore += scored.score

            let pid = slug(p.normalizedName)
            parsedCache[pid] = OceanScoreEngine.uiProduct(from: item, stressIndex: stress)

            let displayName = p.normalizedName.isEmpty
                ? p.rawText
                : p.normalizedName.prefix(1).uppercased() + p.normalizedName.dropFirst()
            items.append(ReceiptItem(name: String(displayName), price: p.price, pid: pid))
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

    // Build + score a FoodItem from the same shape of label signals and env
    // priors the LLM gives us, so receipt originals and LLM-proposed swaps
    // run through identical scoring. Keeps deltaScore meaningful.
    private func scoredFromPriors(
        name: String,
        category: FoodCategory,
        isOrganic: Bool,
        isLocal: Bool,
        packaging: PackagingType,
        classificationConfidence: Double,
        co2: Double?,
        ef: Double?,
        plasticScore: Double?,
        waterLitersPerKg: Int?
    ) -> OceanScoreEngine.Scored {
        var item = OceanScoreEngine.foodItem(
            name: name,
            brand: "",
            category: category,
            barcode: nil,
            isOrganic: isOrganic,
            isLocal: isLocal,
            packaging: packaging,
            classificationConfidence: classificationConfidence
        )
        if item.agribalyseCO2Kg == nil, let v = co2 { item.agribalyseCO2Kg = v }
        if item.agribalyseEF    == nil, let v = ef  { item.agribalyseEF = v }
        if item.plasticScore    == nil, let v = plasticScore { item.plasticScore = v }
        if item.waterScore      == nil, let v = waterLitersPerKg {
            item.waterLitersPerKg = v
            item.waterScore = 1.0 - min(Double(v) / 15000.0, 1.0)
        }
        return OceanScoreEngine.score(item, stressIndex: ocean.stressIndex)
    }

    // Second LLM call: ask for two realistic swaps given what the user bought,
    // score the proposed alternatives through OceanScoreEngine, and publish a
    // fresh Receipt with the swaps filled in. No-op if the client isn't
    // configured or fewer than two items were parsed.
    private func fetchSwaps(originals: [ReceiptScanClient.ParsedItem]) async {
        guard SwapSuggestionClient.isConfigured else {
            ScanLog.llm(40, "SwapSuggestionClient not configured — skipping swap call")
            return
        }
        guard originals.count >= 2 else {
            ScanLog.llm(40, "fewer than 2 items parsed — skipping swap call")
            return
        }

        var originalScores: [String: OceanScoreEngine.Scored] = [:]
        var inputs: [SwapSuggestionClient.InputItem] = []
        for p in originals {
            let scored = scoredFromPriors(
                name: p.normalizedName,
                category: p.category,
                isOrganic: p.isOrganic,
                isLocal: p.isLocal,
                packaging: p.packagingType,
                classificationConfidence: p.classificationConfidence,
                co2: p.co2TotalKg,
                ef: p.efTotal,
                plasticScore: p.plasticScore,
                waterLitersPerKg: p.waterLitersPerKg
            )
            originalScores[p.rawText] = scored
            inputs.append(SwapSuggestionClient.InputItem(
                rawText: p.rawText,
                normalizedName: p.normalizedName,
                category: p.category,
                score: scored.score
            ))
        }

        do {
            let suggestions = try await SwapSuggestionClient.suggest(items: inputs)
            var swaps: [ReceiptSwap] = []
            for s in suggestions {
                guard let fromScored = originalScores[s.fromRawText] else {
                    ScanLog.llm(46, "swap references unknown raw_text='\(s.fromRawText)' — dropping")
                    continue
                }
                let toScored = scoredFromPriors(
                    name: s.toNormalizedName,
                    category: s.toCategory,
                    isOrganic: s.toIsOrganic,
                    isLocal: s.toIsLocal,
                    packaging: s.toPackagingType,
                    classificationConfidence: s.toCategory == .unknown ? 0.3 : 0.75,
                    co2: s.toCo2TotalKg,
                    ef: s.toEfTotal,
                    plasticScore: s.toPlasticScore,
                    waterLitersPerKg: s.toWaterLitersPerKg
                )
                let dPts = toScored.displayPoints - fromScored.displayPoints
                let dScore = toScored.score - fromScored.score
                // An LLM-proposed "swap" that doesn't actually earn more sea
                // bucks isn't a useful suggestion — drop it instead of
                // rendering a negative delta in the UI.
                guard dPts > 0 else {
                    ScanLog.llm(46, "dropping swap '\(s.fromNormalizedName)' → '\(s.toNormalizedName)' (delta_pts=\(dPts))")
                    continue
                }
                swaps.append(ReceiptSwap(
                    fromName: capitalizedFirst(s.fromNormalizedName),
                    toName: capitalizedFirst(s.toNormalizedName),
                    toCategoryLabel: s.toCategory.sectionLabel,
                    fromScore: fromScored.score,
                    toScore: toScored.score,
                    deltaScore: dScore,
                    deltaPoints: dPts,
                    rationale: s.rationale
                ))
            }
            ScanLog.llm(47, "swaps scored: \(swaps.count) → republish liveReceipt")
            if var r = self.liveReceipt {
                r.swaps = swaps
                self.liveReceipt = r
            }
        } catch {
            ScanLog.llm(46, "swap suggest FAILED: \(error)")
        }
    }

    private func capitalizedFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
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
