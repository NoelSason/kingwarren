import Foundation

// One row per scan (product OR receipt). Mirrors the `scans` table we'll
// create in Supabase. For now it also backs a local, in-memory history so
// the Scan history screen has something to render before credentials land.
struct ScanRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: String?
    let kind: Kind
    let productId: String?
    let productName: String
    let score: Int
    let points: Int
    let store: String?
    let createdAt: Date

    enum Kind: String, Codable, Hashable { case product, receipt }

    static func product(_ p: Product, points: Int, userId: String? = nil) -> ScanRecord {
        ScanRecord(id: UUID(), userId: userId, kind: .product,
                   productId: p.id, productName: p.name,
                   score: p.score, points: points, store: nil,
                   createdAt: Date())
    }

    static func receipt(_ r: Receipt, userId: String? = nil) -> ScanRecord {
        ScanRecord(id: UUID(), userId: userId, kind: .receipt,
                   productId: nil,
                   productName: "Basket · \(r.items.count) items",
                   score: r.averageScore, points: r.earned,
                   store: r.store, createdAt: Date())
    }
}

@MainActor
final class ScanHistoryStore: ObservableObject {

    @Published private(set) var records: [ScanRecord] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String? = nil

    private let supabase = SupabaseClient.shared
    private let table = "scans"

    // Append locally immediately; also POST to Supabase if configured.
    func log(_ record: ScanRecord) {
        records.insert(record, at: 0)
        guard supabase.isConfigured else { return }
        Task { [record] in
            do { try await supabase.post(table, body: record) }
            catch { await MainActor.run { self.lastError = "Sync failed." } }
        }
    }

    func refresh() async {
        guard supabase.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let query: [URLQueryItem] = [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order",  value: "created_at.desc"),
                URLQueryItem(name: "limit",  value: "50")
            ]
            let rows: [ScanRecord] = try await supabase.get(table, query: query)
            self.records = rows
            self.lastError = nil
        } catch {
            self.lastError = "Couldn't load scan history."
        }
    }
}
