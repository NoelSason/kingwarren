import SwiftUI

struct RewardsView: View {
    @EnvironmentObject var router: AppRouter

    private var user: UserProfile { Mock.warren }
    private var featured: Reward? { Mock.rewards.first { $0.featured } }
    private var others: [Reward] { Mock.rewards.filter { !$0.featured } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header.padding(.horizontal, 20).padding(.top, 60)

                balanceCard.padding(.horizontal, 16).padding(.top, 14)

                SectionHeader(title: "Featured")
                if let f = featured {
                    featuredCard(f).padding(.horizontal, 16)
                }

                SectionHeader(title: "For you")
                catalogList.padding(.horizontal, 16)

                Spacer().frame(height: 30)
            }
            .padding(.bottom, 110)
        }
        .background(Color.bg.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rewards").font(.serif(32))
            Text("Redeem sea bucks for brands aligned with what your scans say you care about.")
                .font(.system(size: 13))
                .foregroundStyle(Color.ink2)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var balanceCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.1))
                IconWave(size: 24).foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("BALANCE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.6))
                (Text("\(user.points.formatted())").font(.serif(30))
                 + Text(" sea bucks").font(.system(size: 13)).foregroundColor(.white.opacity(0.7)))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {} label: {
                Text("History")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.ink)
        )
    }

    private func featuredCard(_ r: Reward) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(r.brand.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color(hex: 0x6B5410))
            Text(r.title)
                .font(.serif(26))
                .padding(.top, 4)
                .lineSpacing(2)
            Text("Regenerative ocean farming. Mussel beds filter water and sequester carbon.")
                .font(.system(size: 13))
                .foregroundStyle(Color.ink2)
                .padding(.top, 6)
                .lineSpacing(2)
            HStack(spacing: 10) {
                Button {} label: {
                    Text("Redeem · \(r.cost.formatted())")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(Capsule().fill(Color.ink))
                }
                .buttonStyle(.plain)
                Text(r.tag)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ink2)
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0xF1EBDE), Color(hex: 0xE3D4A8)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
    }

    private var catalogList: some View {
        VStack(spacing: 8) {
            ForEach(others) { r in
                rewardRow(r)
            }
        }
    }

    private func rewardRow(_ r: Reward) -> some View {
        let canAfford = r.cost <= user.points
        let initials = String(r.brand.split(separator: " ").compactMap { $0.first }.prefix(2))
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: 0xF0EFE9))
                Text(initials.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.ink2)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 1) {
                Text(r.brand.uppercased())
                    .font(.system(size: 11, weight: .regular))
                    .tracking(1)
                    .foregroundStyle(Color.ink3)
                Text(r.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineSpacing(2)
                Text(r.tag)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ink2)
                    .padding(.top, 3)
            }
            Spacer()

            Button {} label: {
                Text(r.cost.formatted())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(canAfford ? .white : Color.ink3)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(
                        Capsule().fill(canAfford ? Color.ink : Color(hex: 0xF0EFE9))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canAfford)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.hair, lineWidth: 1)
                )
        )
    }
}
