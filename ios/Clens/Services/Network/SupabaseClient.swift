import Foundation

// Thin REST client over a Supabase project. Reads URL and anon key from
// Info.plist keys `SUPABASE_URL` and `SUPABASE_ANON_KEY`, which are left
// blank in source — fill them via xcconfig or a local secrets file before
// the demo. While `isConfigured == false` the client no-ops.
final class SupabaseClient: @unchecked Sendable {

    static let shared = SupabaseClient()

    let baseURL: URL?
    let anonKey: String?
    private let session: URLSession
    private let tokenLock = NSLock()
    private var _accessToken: String?

    private init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let raw = (info["SUPABASE_URL"] as? String) ?? ""
        self.baseURL = URL(string: raw)
        let key = (info["SUPABASE_ANON_KEY"] as? String) ?? ""
        self.anonKey = key.isEmpty ? nil : key
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.waitsForConnectivity = true
        self.session = URLSession(configuration: cfg)
    }

    var isConfigured: Bool { baseURL != nil && anonKey != nil }

    func setAccessToken(_ token: String?) {
        tokenLock.lock(); defer { tokenLock.unlock() }
        _accessToken = token
    }

    func currentAccessToken() -> String? {
        tokenLock.lock(); defer { tokenLock.unlock() }
        return _accessToken
    }

    // Reads the signed-in user's row from public.profiles. RLS scopes the
    // result to auth.uid(), so the only row that comes back is the caller's.
    func fetchCurrentUserProfile() async throws -> DatabricksProfile {
        let rows: [DatabricksProfile] = try await get("rest/v1/profiles")
        guard let first = rows.first else {
            throw SupabaseError.http(status: 404, body: "profile not found — RLS may be blocking, or row missing")
        }
        return first
    }

    struct ClaimedRewardRow: Decodable {
        let rewardId: String
        let rewardBrand: String
        let rewardTitle: String
        let rewardCost: Int
        let rewardStore: String
        let rewardTag: String
        let rewardBarcode: String
        let claimedAt: String
    }

    func fetchClaimedRewards() async throws -> [ClaimedRewardRow] {
        try await get("rest/v1/claimed_rewards", query: [
            URLQueryItem(name: "order", value: "claimed_at.desc")
        ])
    }

    private struct RedeemBody: Encodable {
        let rewardId: String
        let rewardBrand: String
        let rewardTitle: String
        let rewardCost: Int
        let rewardStore: String
        let rewardTag: String
        let rewardBarcode: String
    }

    // Calls the redeem_reward RPC which atomically checks the balance,
    // deducts the cost, writes a claimed_rewards row, and returns the new
    // seabucks balance. Throws if the user has insufficient funds.
    func redeemReward(_ reward: Reward) async throws -> Int {
        let rewardID = reward.barcode.isEmpty
            ? "\(reward.brand)|\(reward.title)"
            : reward.barcode
        let body = RedeemBody(
            rewardId: rewardID,
            rewardBrand: reward.brand,
            rewardTitle: reward.title,
            rewardCost: reward.cost,
            rewardStore: reward.store,
            rewardTag: reward.tag,
            rewardBarcode: reward.barcode
        )
        return try await postReturning("rest/v1/rpc/redeem_reward", body: body)
    }

    // MARK: - Low-level REST

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let req = try buildRequest(path: path, method: "GET", query: query, body: Optional<EmptyBody>.none)
        return try await send(req)
    }

    func postReturning<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = try buildRequest(path: path, method: "POST", query: [], body: body)
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        return try await send(req)
    }

    @discardableResult
    func post<B: Encodable>(_ path: String, body: B) async throws -> Data {
        let req = try buildRequest(path: path, method: "POST", query: [], body: body)
        return try await sendRaw(req)
    }

    // MARK: - Plumbing

    private func buildRequest<B: Encodable>(path: String,
                                            method: String,
                                            query: [URLQueryItem],
                                            body: B?) throws -> URLRequest {
        guard let baseURL, let anonKey else { throw SupabaseError.notConfigured }
        var comps = URLComponents(url: baseURL.appendingPathComponent(path),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = query.isEmpty ? nil : query
        guard let url = comps?.url else { throw SupabaseError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        let bearer = currentAccessToken() ?? anonKey
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")

        if let body {
            req.httpBody = try JSONEncoder.supabase.encode(body)
        }
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data = try await sendRaw(req)
        do { return try JSONDecoder.supabase.decode(T.self, from: data) }
        catch { throw SupabaseError.decoding(error) }
    }

    private func sendRaw(_ req: URLRequest) async throws -> Data {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw SupabaseError.transport }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        return data
    }
}

private struct EmptyBody: Encodable {}

enum SupabaseError: Error {
    case notConfigured
    case badURL
    case transport
    case http(status: Int, body: String?)
    case decoding(Error)
}

extension JSONEncoder {
    static let supabase: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
}

extension JSONDecoder {
    static let supabase: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
