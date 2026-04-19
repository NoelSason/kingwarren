import Foundation

struct DatabricksProfile: Decodable {
    let id: String
    let displayName: String
    let username: String
    let email: String
    let seabucks: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case email
        case seabucks
        case createdAt = "created_at"
    }
}

struct OceanStressPayload: Decodable {
    let stressIndex: Double
    let location: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case stressIndex = "stress_index"
        case location
        case updatedAt = "updated_at"
    }
}

enum APIError: LocalizedError {
    case badURL
    case server(String)
    case notFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid API URL."
        case .server(let msg): return msg
        case .notFound: return "Not found."
        case .unknown: return "Unknown error."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession

    private init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let raw = (info["API_BASE_URL"] as? String) ?? "http://127.0.0.1:5000"
        baseURL = URL(string: raw) ?? URL(string: "http://127.0.0.1:5000")!
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        session = URLSession(configuration: cfg)
    }

    // MARK: - Profile

    func upsertProfile(userID: String, email: String, username: String, displayName: String) async throws {
        let url = baseURL.appendingPathComponent("/api/profile")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "user_id": userID,
            "email": email,
            "username": username,
            "display_name": displayName,
        ])
        let (data, resp) = try await session.data(for: req)
        try checkStatus(data: data, resp: resp)
    }

    func fetchProfile(userID: String) async throws -> DatabricksProfile {
        let url = baseURL.appendingPathComponent("/api/profile/\(userID)")
        let req = URLRequest(url: url)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 { throw APIError.notFound }
        try checkStatus(data: data, resp: resp)
        return try JSONDecoder().decode(DatabricksProfile.self, from: data)
    }

    // MARK: - Ocean stress

    func fetchOceanStress() async throws -> OceanStressPayload {
        let url = baseURL.appendingPathComponent("/api/ocean-stress")
        let (data, resp) = try await session.data(for: URLRequest(url: url))
        try checkStatus(data: data, resp: resp)
        return try JSONDecoder().decode(OceanStressPayload.self, from: data)
    }

    // MARK: - Helpers

    private func checkStatus(data: Data, resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse else { throw APIError.unknown }
        guard (200..<300).contains(http.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let msg = json?["error"] as? String ?? "Error \(http.statusCode)"
            throw APIError.server(msg)
        }
    }
}
