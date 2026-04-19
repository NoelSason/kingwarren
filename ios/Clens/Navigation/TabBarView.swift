import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        HStack(spacing: 0) {
            tab(.home,        label: "Home")    { IconHome(size: 22) }
            tab(.rewards,     label: "Rewards") { IconGift(size: 22) }
            scanButton
            tab(.leaderboard, label: "Board")   { IconTrophy(size: 22) }
            tab(.profile,     label: "Profile") { IconUser(size: 22) }
        }
        .padding(.top, 8)
        .padding(.bottom, 28)
        .frame(height: 92)
        .background(
            ZStack {
                Color.bg.opacity(0.85)
                Rectangle().fill(.ultraThinMaterial).opacity(0.85)
            }
        )
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1),
            alignment: .top
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
                        .fill(Color.ink)
                        .frame(width: 52, height: 52)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                    IconScan(size: 22)
                        .foregroundStyle(Color.white)
                }
                .offset(y: -14)

                Text("Scan")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(Color.ink3)
                    .offset(y: -14)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
