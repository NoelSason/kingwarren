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
        if let p = try? await SupabaseClient.shared.fetchCurrentUserProfile() {
            profile = p
            balance = p.seabucks
            return
        }
        if let p = try? await APIClient.shared.fetchProfile(userID: userID) {
            profile = p
            balance = p.seabucks
        }
    }

    func redeem(_ reward: Reward) -> Bool {
        guard balance >= reward.cost else { return false }
        balance -= reward.cost
        claimedRewards.insert(ClaimedReward(reward: reward, claimedAt: Date()), at: 0)
        return true
    }
}
