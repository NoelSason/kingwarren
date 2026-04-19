import SwiftUI

enum Tab: String, CaseIterable, Hashable {
    case home, rewards, scan, leaderboard, profile
}

enum ScanMode: String, Hashable {
    case product, receipt
}

enum Route: Hashable {
    case scan
    case scanResult(pid: String)
    case swap(pid: String)
    case receipt
    case scanHistory
    case myRewards
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var authed: Bool = false
    @Published var tab: Tab = .home
    @Published var stack: [Route] = []
    @Published var scanMode: ScanMode = .product
    @Published var session: AuthSession? {
        didSet {
            if let session {
                SessionStore.save(session)
                SupabaseClient.shared.setAccessToken(session.accessToken)
            } else {
                SessionStore.clear()
                SupabaseClient.shared.setAccessToken(nil)
            }
        }
    }

    init() {
        if let saved = SessionStore.load() {
            self.session = saved
            self.authed = true
            SupabaseClient.shared.setAccessToken(saved.accessToken)
        }
    }

    var top: Route? { stack.last }
    var showsScan: Bool {
        if case .scan = top { return true } else { return false }
    }

    func push(_ route: Route) { stack.append(route) }
    func pop() { _ = stack.popLast() }
    func reset() { stack.removeAll() }

    func signOut() {
        stack.removeAll()
        tab = .home
        session = nil
        authed = false
    }

    func selectTab(_ next: Tab) {
        reset()
        if next == .scan {
            scanMode = .product
            push(.scan)
        } else {
            tab = next
        }
    }
}
