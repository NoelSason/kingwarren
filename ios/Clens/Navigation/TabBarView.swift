import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var router: AppRouter

    private var safeBottomInset: CGFloat {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.windows.first?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            tab(.home,        label: "Home")    { IconHome(size: 22) }
            tab(.rewards,     label: "Rewards") { IconGift(size: 22) }
            scanButton
            tab(.leaderboard, label: "Board")   { IconTrophy(size: 22) }
            tab(.profile,     label: "Profile") { IconUser(size: 22) }
        }
        .padding(.top, 4)
        .padding(.bottom, max(safeBottomInset - 4, 10))
        .background(
            Color.bg
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 1),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tab(_ id: Tab, label: String, icon: () -> some View) -> some View {
        let active = router.tab == id && !router.showsScan
        return Button {
            router.selectTab(id)
        } label: {
            VStack(spacing: 4) {
                icon()
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.3)
            }
            .foregroundStyle(active ? Color.ink : Color.ink3)
            .frame(maxWidth: .infinity)
        }
    }

    private var scanButton: some View {
        Button {
            router.selectTab(.scan)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.ocean)
                        .frame(width: 52, height: 52)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                    IconScan(size: 22)
                        .foregroundStyle(Color.white)
                }
                .offset(y: -8)

                Text("Scan")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(Color.ink3)
                    .offset(y: -8)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
