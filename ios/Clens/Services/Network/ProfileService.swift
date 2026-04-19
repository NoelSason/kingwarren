import Foundation

@MainActor
final class ProfileService: ObservableObject {
    @Published private(set) var profile: DatabricksProfile?
    @Published private(set) var isLoading = false

    // Local mutable overlay so redeem flows update UI across Home/Rewards/Profile
    // without waiting on a backend round-trip. Seeded at 0 so a first-time
    // user never sees a mock balance before load() returns.
    @Published var balance: Int = 0
    @Published var claimedRewards: [ClaimedReward] = []

    func load(userID: String) async {
        isLoading = true
        defer { isLoading = false }

        // Supabase is the source of truth for seabucks now — scans insert into
        // public.scans and bump the balance via the add_seabucks RPC. Fall back
        // to Databricks only if Supabase is unreachable so the UI still has a
        // value when offline.
        var loadedFromSupabase = false
        do {
            let p = try await SupabaseClient.shared.fetchCurrentUserProfile()
            profile = p
            balance = p.seabucks
            loadedFromSupabase = true
            print("[PROFILE] Supabase load OK: seabucks=\(p.seabucks)")
        } catch {
            print("[PROFILE] Supabase load FAILED: \(error) — falling back to Databricks")
        }

        if !loadedFromSupabase {
            do {
                let p = try await APIClient.shared.fetchProfile(userID: userID)
                profile = p
                balance = p.seabucks
                print("[PROFILE] Databricks load OK: seabucks=\(p.seabucks)")
            } catch {
                print("[PROFILE] Databricks load FAILED: \(error) — balance stays at \(balance)")
            }
        }

        // Pull the user's claimed rewards so the Rewards / Profile screens
        // persist across relaunches instead of resetting to an empty list.
        if let rows = try? await SupabaseClient.shared.fetchClaimedRewards() {
            claimedRewards = rows.map { row in
                let reward = Reward(
                    brand: row.rewardBrand,
                    title: row.rewardTitle,
                    cost: row.rewardCost,
                    tag: row.rewardTag,
                    featured: false,
                    store: row.rewardStore,
                    barcode: row.rewardBarcode
                )
                return ClaimedReward(reward: reward, claimedAt: parseDate(row.claimedAt))
            }
            print("[PROFILE] Supabase claimed rewards loaded: \(claimedRewards.count)")
        } else {
            print("[PROFILE] claimed rewards fetch skipped or failed")
        }
    }

    func redeem(_ reward: Reward) async -> Bool {
        do {
            let newBalance = try await SupabaseClient.shared.redeemReward(reward)
            balance = newBalance
            claimedRewards.insert(ClaimedReward(reward: reward, claimedAt: Date()), at: 0)
            print("[REDEEM] OK — new balance=\(newBalance)")
            return true
        } catch {
            print("[REDEEM] FAILED: \(error)")
            return false
        }
    }

    private func parseDate(_ iso: String) -> Date {
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: iso) { return d }
        return ISO8601DateFormatter().date(from: iso) ?? Date()
    }
}
