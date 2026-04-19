import Foundation

@MainActor
final class ProfileService: ObservableObject {
    @Published private(set) var profile: DatabricksProfile?
    @Published private(set) var isLoading = false

    // Local source of truth for balance + claimed rewards. Every account is
    // seeded with 500 seabucks on first login so the demo never starts at 0,
    // and redeems/credits mutate this list directly — Supabase is attempted
    // best-effort but never blocks the UI.
    @Published var balance: Int = 0
    @Published var claimedRewards: [ClaimedReward] = []

    private let defaults = UserDefaults.standard
    private let initialSeed = 500
    private var currentUserID: String?

    private func balanceKey(_ uid: String) -> String { "clens.profile.balance.\(uid)" }
    private func claimedKey(_ uid: String) -> String { "clens.profile.claimed.\(uid)" }
    private func seededKey(_ uid: String) -> String { "clens.profile.seeded.\(uid)" }

    func load(userID: String) async {
        isLoading = true
        defer { isLoading = false }
        currentUserID = userID

        if !defaults.bool(forKey: seededKey(userID)) {
            defaults.set(initialSeed, forKey: balanceKey(userID))
            defaults.set(true, forKey: seededKey(userID))
            print("[PROFILE] seeded new user \(userID) with \(initialSeed) seabucks")
        }

        balance = defaults.integer(forKey: balanceKey(userID))
        claimedRewards = loadClaimed(userID: userID)
        print("[PROFILE] local load OK: seabucks=\(balance) claimed=\(claimedRewards.count)")

        // Best-effort remote sync — never overwrites local state on failure,
        // and we don't wait on it to render the UI.
        Task { [weak self] in
            guard let self = self else { return }
            if let p = try? await SupabaseClient.shared.fetchCurrentUserProfile() {
                await MainActor.run {
                    self.profile = p
                    print("[PROFILE] Supabase profile metadata synced (balance stays local)")
                }
            }
        }
    }

    // Called from ScanCoordinator after a receipt scores. Persists immediately
    // so Home / Rewards / Profile reflect the new total on the next frame.
    func credit(_ amount: Int) {
        guard amount > 0 else { return }
        balance += amount
        persistBalance()
        print("[PROFILE] credited +\(amount) → balance=\(balance)")
    }

    // Always succeeds when the user can afford it — Supabase is a fire-and-
    // forget write, not a gate.
    func redeem(_ reward: Reward) async -> Bool {
        guard balance >= reward.cost else {
            print("[REDEEM] insufficient balance=\(balance) cost=\(reward.cost)")
            return false
        }
        balance -= reward.cost
        claimedRewards.insert(ClaimedReward(reward: reward, claimedAt: Date()), at: 0)
        persistBalance()
        persistClaimed()
        print("[REDEEM] local OK — new balance=\(balance)")

        Task {
            _ = try? await SupabaseClient.shared.redeemReward(reward)
        }
        return true
    }

    private func persistBalance() {
        guard let uid = currentUserID else { return }
        defaults.set(balance, forKey: balanceKey(uid))
    }

    private func persistClaimed() {
        guard let uid = currentUserID else { return }
        let records = claimedRewards.map { ClaimedRewardRecord(from: $0) }
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: claimedKey(uid))
        }
    }

    private func loadClaimed(userID: String) -> [ClaimedReward] {
        guard let data = defaults.data(forKey: claimedKey(userID)),
              let records = try? JSONDecoder().decode([ClaimedRewardRecord].self, from: data)
        else { return [] }
        return records.map { $0.toClaimedReward() }
    }
}

// Disk-persistable mirror of ClaimedReward. Kept local to ProfileService so
// the domain model doesn't need to adopt Codable.
private struct ClaimedRewardRecord: Codable {
    let brand: String
    let title: String
    let cost: Int
    let tag: String
    let store: String
    let barcode: String
    let claimedAt: Date

    init(from c: ClaimedReward) {
        self.brand = c.reward.brand
        self.title = c.reward.title
        self.cost = c.reward.cost
        self.tag = c.reward.tag
        self.store = c.reward.store
        self.barcode = c.reward.barcode
        self.claimedAt = c.claimedAt
    }

    func toClaimedReward() -> ClaimedReward {
        ClaimedReward(
            reward: Reward(
                brand: brand,
                title: title,
                cost: cost,
                tag: tag,
                featured: false,
                store: store,
                barcode: barcode
            ),
            claimedAt: claimedAt
        )
    }
}
