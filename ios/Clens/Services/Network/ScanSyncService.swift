import Foundation

// Persists a completed receipt scan to Supabase and atomically bumps the
// signed-in user's seabucks balance via the add_seabucks RPC. Returns the
// new balance so callers can update in-memory profile state. RLS requires
// a valid user JWT (wired via SupabaseClient.setAccessToken at sign-in).
enum ScanSyncService {

    private struct ScanRow: Encodable {
        let userId: String
        let store: String
        let total: Double
        let oceanScore: Int
        let seabucksEarned: Int
        let itemCount: Int
        let items: [ScanItemRow]
    }

    private struct ScanItemRow: Encodable {
        let name: String
        let price: Double
        let pid: String
    }

    private struct AddSeabucksBody: Encodable {
        let amount: Int
    }

    enum SyncError: Error {
        case notConfigured
        case decoding
    }

    static func sync(userID: String, receipt: Receipt) async throws -> Int {
        guard SupabaseClient.shared.isConfigured else { throw SyncError.notConfigured }

        let rows = receipt.items.map {
            ScanItemRow(name: $0.name, price: $0.price, pid: $0.pid)
        }
        let row = ScanRow(
            userId: userID,
            store: receipt.store,
            total: receipt.total,
            oceanScore: receipt.averageScore,
            seabucksEarned: receipt.earned,
            itemCount: receipt.items.count,
            items: rows
        )
        _ = try await SupabaseClient.shared.post("rest/v1/scans", body: [row])

        let body = AddSeabucksBody(amount: receipt.earned)
        let newBalance: Int = try await SupabaseClient.shared.postReturning(
            "rest/v1/rpc/add_seabucks",
            body: body
        )
        return newBalance
    }
}
