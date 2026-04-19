import SwiftUI

struct RootView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            if !router.authed {
                SignInView()
                    .transition(.opacity)
            } else {
                ZStack(alignment: .bottom) {
                    content
                    if !router.showsScan {
                        TabBarView()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.authed)
    }

    @ViewBuilder
    private var content: some View {
        if let top = router.top {
            switch top {
            case .scan:
                ScanView()
            case .scanResult(let pid):
                ScanResultView(pid: pid)
            case .swap(let pid):
                SwapView(pid: pid)
            case .receipt:
                ReceiptResultView()
            case .scanHistory:
                ScanHistoryView()
            case .myRewards:
                ClaimedRewardsView()
            }
        } else {
            switch router.tab {
            case .home:        HomeView()
            case .rewards:     RewardsView()
            case .leaderboard: LeaderboardView()
            case .profile:     ProfileView()
            case .scan:        ScanView()
            }
        }
    }
}
