import SwiftUI

enum Tab: String, CaseIterable, Hashable {
    case home, rewards, scan, leaderboard, profile
}

enum ScanMode: String, Hashable {
    case product, receipt, recycle
}

enum Route: Hashable {
    case scan
    case scanResult(pid: String)
    case swap(pid: String)
    case receipt
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var authed: Bool = false
    @Published var tab: Tab = .home
    @Published var stack: [Route] = []
    @Published var scanMode: ScanMode = .product

    var top: Route? { stack.last }
    var showsScan: Bool {
        if case .scan = top { return true } else { return false }
    }

    func push(_ route: Route) { stack.append(route) }
    func pop() { _ = stack.popLast() }
    func reset() { stack.removeAll() }

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
