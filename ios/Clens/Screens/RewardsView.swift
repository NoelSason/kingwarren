import SwiftUI

struct RewardsView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var profileService: ProfileService

    @State private var pendingRedeem: Reward?
    @State private var showSuccessFor: Reward?

    private var balance: Int { profileService.balance }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header.padding(.horizontal, 20).padding(.top, 24)
                balanceCard.padding(.horizontal, 16).padding(.top, 14)

                SectionHeader(title: "Grocery coupons")
                catalogList.padding(.horizontal, 16)
            }
            .padding(.bottom, 96)
        }
        .background(Color.bg.ignoresSafeArea())
        .sheet(item: $pendingRedeem) { reward in
            RedeemConfirmSheet(
                reward: reward,
                balance: balance,
                onConfirm: {
                    Task {
                        if await profileService.redeem(reward) {
                            pendingRedeem = nil
                            showSuccessFor = reward
                        }
                    }
                },
                onCancel: { pendingRedeem = nil }
            )
            .presentationDetents([.medium])
        }
        .alert("Reward claimed",
               isPresented: Binding(
                    get: { showSuccessFor != nil },
                    set: { if !$0 { showSuccessFor = nil } }
               ),
               presenting: showSuccessFor) { _ in
            Button("View my rewards") {
                showSuccessFor = nil
                router.push(.myRewards)
            }
            Button("Done", role: .cancel) { showSuccessFor = nil }
        } message: { r in
            Text("\(r.title) saved. Show the barcode at checkout to redeem.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Rewards").font(.serif(32))
                Spacer()
                Button {
                    router.push(.myRewards)
                } label: {
                    Text("My rewards")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ocean)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View my claimed rewards")
            }
            Text("Use seabucks to claim rewards and discounts at listed grocery stores.")
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
                (Text("\(balance.formatted())").font(.serif(30))
                 + Text(" seabucks").font(.system(size: 13)).foregroundColor(.white.opacity(0.7)))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { router.push(.myRewards) } label: {
                Text("Claimed")
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
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.ocean)
        )
    }

    private var catalogList: some View {
        VStack(spacing: 8) {
            ForEach(Mock.rewards) { r in
                rewardRow(r)
            }
        }
    }

    private func rewardRow(_ r: Reward) -> some View {
        let canAfford = r.cost <= balance
        return Button {
            pendingRedeem = r
        } label: {
            HStack(spacing: 12) {
                StoreBadge(store: r.store)
                VStack(alignment: .leading, spacing: 1) {
                    Text(r.store.uppercased())
                        .font(.system(size: 10.5, weight: .regular))
                        .tracking(1)
                        .foregroundStyle(Color.ink3)
                    Text(r.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(r.tag)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ink2)
                        .padding(.top, 3)
                }
                Spacer(minLength: 8)
                Text("\(r.cost.formatted())")
                    .font(.mono(12, weight: .semibold))
                    .foregroundStyle(canAfford ? .white : Color.ink2)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(
                        Capsule().fill(canAfford ? Color.ocean : Color.fill1)
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
        .buttonStyle(.plain)
        .disabled(!canAfford)
        .opacity(canAfford ? 1.0 : 0.6)
        .accessibilityLabel("\(r.store): \(r.title), \(r.cost) seabucks")
    }
}

private struct StoreBadge: View {
    let store: String

    private var initials: String {
        String(store.split(separator: " ").compactMap { $0.first }.prefix(2)).uppercased()
    }

    private var bg: Color {
        switch store.lowercased() {
        case "ralphs":        return Color(hex: 0xD93A2B)
        case "trader joe's":  return Color(hex: 0xB3312A)
        case "sprouts":       return Color(hex: 0x5A8F3A)
        case "vons":          return Color(hex: 0xC62033)
        case "whole foods":   return Color(hex: 0x006B5E)
        default:              return Color.ocean
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(bg)
            Text(initials)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)
    }
}

private struct RedeemConfirmSheet: View {
    let reward: Reward
    let balance: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var afterBalance: Int { max(0, balance - reward.cost) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Redeem this reward?")
                    .font(.serif(22))
                Spacer()
                Button(action: onCancel) {
                    ZStack {
                        Circle().fill(Color.fill1).frame(width: 30, height: 30)
                        Text("✕").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ink2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.bottom, 18)

            HStack(spacing: 12) {
                StoreBadgePublic(store: reward.store)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reward.store.uppercased())
                        .font(.system(size: 10.5, weight: .regular))
                        .tracking(1)
                        .foregroundStyle(Color.ink3)
                    Text(reward.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(2)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.fill1)
            )
            .padding(.bottom, 16)

            balanceRow("Current balance", value: "\(balance.formatted()) seabucks", emphasized: false)
            balanceRow("Cost", value: "-\(reward.cost.formatted()) seabucks", emphasized: false)
            Color.hair.frame(height: 1).padding(.vertical, 10)
            balanceRow("After redeem", value: "\(afterBalance.formatted()) seabucks", emphasized: true)

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.fill1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text("Yes, redeem")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.ocean)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bg.ignoresSafeArea())
    }

    private func balanceRow(_ label: String, value: String, emphasized: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.ink2)
            Spacer()
            Text(value)
                .font(.mono(13, weight: emphasized ? .bold : .regular))
                .foregroundStyle(emphasized ? Color.ink : Color.ink2)
        }
        .padding(.vertical, 4)
    }
}

// Publicly visible store badge for use inside the sheet file (the private one
// above is scoped to the catalog list).
private struct StoreBadgePublic: View {
    let store: String
    private var initials: String {
        String(store.split(separator: " ").compactMap { $0.first }.prefix(2)).uppercased()
    }
    private var bg: Color {
        switch store.lowercased() {
        case "ralphs":        return Color(hex: 0xD93A2B)
        case "trader joe's":  return Color(hex: 0xB3312A)
        case "sprouts":       return Color(hex: 0x5A8F3A)
        case "vons":          return Color(hex: 0xC62033)
        case "whole foods":   return Color(hex: 0x006B5E)
        default:              return Color.ocean
        }
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bg)
            Text(initials)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)
    }
}
