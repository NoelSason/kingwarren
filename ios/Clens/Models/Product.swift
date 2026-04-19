import Foundation

struct Product: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String
    let size: String
    let score: Int
    let category: String
    let breakdown: Breakdown
    let facts: [String]
    let origin: String
    let badges: [String]
    var imageURL: String? = nil

    struct Breakdown: Hashable {
        let climate: Int
        let runoff: Int
        let plastic: Int
        let water: Int
    }
}

struct Swap: Hashable {
    let from: String
    let to: String
    let altName: String
    let deltaScore: Int
    let deltaPoints: Int
    let pros: [String]
    let cons: [String]
}

struct ReceiptItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let price: Double
    let pid: String
}

struct Receipt: Hashable {
    let store: String
    let date: String
    let total: Double
    let items: [ReceiptItem]
    let earned: Int
    let averageScore: Int
    // Populated a moment after items are scored by a second LLM call
    // (SwapSuggestionClient). Empty on first publish; ReceiptResultView
    // re-renders once the suggestions arrive.
    var swaps: [ReceiptSwap] = []
}

struct ReceiptSwap: Identifiable, Hashable {
    let id = UUID()
    let fromName: String
    let toName: String
    let toCategoryLabel: String       // e.g. "Legume · Dry"
    let fromScore: Int
    let toScore: Int
    let deltaScore: Int               // toScore - fromScore
    let deltaPoints: Int              // displayPoints delta (sea bucks style)
    let rationale: String
}

enum FeedItem: Identifiable, Hashable {
    case haul(who: String, amount: Int, where_: String, time: String, detail: String)
    case ocean(headline: String, detail: String, time: String)
    case nudge(headline: String, detail: String, action: String)
    case friend(who: String, action: String, detail: String, time: String)

    var id: String {
        switch self {
        case .haul(let who, _, _, _, _): return "haul-\(who)"
        case .ocean(let h, _, _): return "ocean-\(h)"
        case .nudge(let h, _, _): return "nudge-\(h)"
        case .friend(let w, _, _, _): return "friend-\(w)"
        }
    }
}

struct Reward: Identifiable, Hashable {
    let id = UUID()
    let brand: String
    let title: String
    let cost: Int
    let tag: String
    let featured: Bool
}

struct Leader: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let rank: Int
    let pts: Int
    let area: String
    let tag: String
    let isMe: Bool
}

struct OceanConditions: Hashable {
    let location: String
    let updated: String
    let stressIndex: Double
    let chlorophyll: String
    let pH: String
    let dissolvedO2: String
    let headline: String
    let detail: String
    let alert: String
}

struct UserProfile: Hashable {
    let name: String
    let handle: String
    let points: Int
    let rank: String
    let streak: Int
    let store: String
    let lastHaul: Int
    let lifetimeCO2: Int      // kg saved
    let lifetimePlastic: Double  // kg avoided
    let lifetimeWater: Int    // L saved
}
