import SwiftUI

struct ClaimedRewardsView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var profileService: ProfileService

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d · h:mm a"
        return f
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topBar.padding(.horizontal, 16).padding(.top, 24)

                header.padding(.horizontal, 20).padding(.top, 10)

                if profileService.claimedRewards.isEmpty {
                    emptyState
                } else {
                    cardList.padding(.horizontal, 16).padding(.top, 14)
                }
            }
            .padding(.bottom, 96)
        }
        .background(Color.bg.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button { router.pop() } label: {
                ZStack {
                    Circle().fill(Color.surface)
                        .overlay(Circle().stroke(Color.hair, lineWidth: 1))
                    IconChevL(size: 18)
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            Spacer()
            Pill(text: "My rewards")
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("My rewards").font(.serif(28))
            Text("Show the barcode at checkout to redeem.")
                .font(.system(size: 13))
                .foregroundStyle(Color.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No claimed rewards yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text("Head back to Rewards and redeem a grocery coupon — it'll show up here with a scannable barcode.")
                .font(.system(size: 13))
                .foregroundStyle(Color.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 30)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }

    private var cardList: some View {
        VStack(spacing: 12) {
            ForEach(profileService.claimedRewards) { cr in
                claimedCard(cr)
            }
        }
    }

    private func claimedCard(_ cr: ClaimedReward) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                claimedStoreBadge(cr.reward.store)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cr.reward.store.uppercased())
                        .font(.system(size: 10.5, weight: .regular))
                        .tracking(1)
                        .foregroundStyle(Color.ink3)
                    Text(cr.reward.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(2)
                    Text("Claimed \(Self.dateFormatter.string(from: cr.claimedAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ink3)
                        .padding(.top, 2)
                }
                Spacer()
                Text("-\(cr.reward.cost.formatted())")
                    .font(.mono(12, weight: .semibold))
                    .foregroundStyle(Color.ink2)
            }

            VStack(spacing: 6) {
                BarcodeImage(code: cr.reward.barcode, height: 64)
                Text(cr.reward.barcode)
                    .font(.mono(11))
                    .foregroundStyle(Color.ink2)
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.hair, lineWidth: 1)
                    )
            )
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

    private func claimedStoreBadge(_ store: String) -> some View {
        let initials = String(store.split(separator: " ").compactMap { $0.first }.prefix(2)).uppercased()
        let bg: Color = {
            switch store.lowercased() {
            case "ralphs":        return Color(hex: 0xD93A2B)
            case "trader joe's":  return Color(hex: 0xB3312A)
            case "sprouts":       return Color(hex: 0x5A8F3A)
            case "vons":          return Color(hex: 0xC62033)
            case "whole foods":   return Color(hex: 0x006B5E)
            default:              return Color.ocean
            }
        }()
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bg)
            Text(initials)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)
    }
}
