import Foundation

struct AuthSession {
    let accessToken: String
    let refreshToken: String
    let userID: String
    let email: String
    let username: String
    let displayName: String
}

enum AuthError: LocalizedError {
    case notConfigured
    case server(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase is not configured."
        case .server(let msg): return msg
        case .unknown: return "Something went wrong. Please try again."
        }
    }
}

final class AuthService {
    static let shared = AuthService()
    private let client = SupabaseClient.shared
    private init() {}

    func signUp(email: String, password: String, username: String, displayName: String) async throws -> AuthSession {
        guard client.isConfigured, let base = client.baseURL, let key = client.anonKey else {
            throw AuthError.notConfigured
        }
        var req = try buildRequest(base: base, key: key, path: "auth/v1/signup")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "data": ["username": username, "display_name": displayName],
        ])
        let session = try await perform(req, username: username, displayName: displayName)
        Task {
            try? await APIClient.shared.upsertProfile(
                userID: session.userID,
                email: session.email,
                username: username,
                displayName: displayName
            )
        }
        return session
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        guard client.isConfigured, let base = client.baseURL, let key = client.anonKey else {
            throw AuthError.notConfigured
        }
        var comps = URLComponents(url: supabaseURL(base: base, path: "auth/v1/token"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        return try await perform(req, username: "", displayName: "")
    }

    private func supabaseURL(base: URL, path: String) -> URL {
        let root = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(root)/\(path)")!
    }

    private func buildRequest(base: URL, key: String, path: String) throws -> URLRequest {
        let url = supabaseURL(base: base, path: path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func perform(_ req: URLRequest, username: String, displayName: String) async throws -> AuthSession {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthError.unknown }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        guard (200..<300).contains(http.statusCode) else {
            let msg = json["error_description"] as? String
                ?? json["msg"] as? String
                ?? json["message"] as? String
                ?? "Error \(http.statusCode)"
            throw AuthError.server(msg)
        }

        guard
            let accessToken = json["access_token"] as? String,
            let refreshToken = json["refresh_token"] as? String,
            let user = json["user"] as? [String: Any],
            let userID = user["id"] as? String,
            let email = user["email"] as? String
        else { throw AuthError.unknown }

        let meta = user["user_metadata"] as? [String: Any] ?? [:]
        let resolvedUsername = (meta["username"] as? String) ?? username
        let resolvedDisplayName = (meta["display_name"] as? String) ?? displayName

        SupabaseClient.shared.setAccessToken(accessToken)

        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: userID,
            email: email,
            username: resolvedUsername,
            displayName: resolvedDisplayName
        )
    }
}
