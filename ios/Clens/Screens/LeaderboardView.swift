import SwiftUI

struct LeaderboardView: View {
    @State private var scope: Scope = .local

    enum Scope: String, CaseIterable, Identifiable {
        case local, friends, global
        var id: Self { self }
        var label: String { rawValue.capitalized }
    }

    private var leaders: [Leader] { Mock.leaders }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header.padding(.horizontal, 20).padding(.top, 60)

                scopeSwitch.padding(.horizontal, 16).padding(.top, 14)

                podiumRow.padding(.horizontal, 20).padding(.top, 22)

                SectionHeader(title: "Everyone else")
                listCard

                SectionHeader(title: "Perks by rank")
                perks.padding(.horizontal, 16)

                Spacer().frame(height: 30)
            }
            .padding(.bottom, 110)
        }
        .background(Color.bg.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Leaderboard").font(.serif(32))
            Text("La Jolla · 92704 · week of Apr 13")
                .font(.system(size: 13))
                .foregroundStyle(Color.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scopeSwitch: some View {
        HStack(spacing: 4) {
            ForEach(Scope.allCases) { s in
                Button { scope = s } label: {
                    Text(s.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(scope == s ? Color.ink : Color.ink2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(scope == s ? Color.surface : Color.clear)
                                .shadow(color: scope == s ? Color.black.opacity(0.08) : .clear,
                                        radius: 1, x: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: 0xF0EFE9))
        )
    }

    private var podiumRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if leaders.count >= 3 {
                Podium(name: leaders[1].name, pts: leaders[1].pts, rank: 2,
                       height: 105, color: Color(hex: 0xBFA67A), crown: false, isMe: leaders[1].isMe)
                Podium(name: leaders[0].name, pts: leaders[0].pts, rank: 1,
                       height: 140, color: Color(hex: 0xE3C96A), crown: true, isMe: leaders[0].isMe)
                Podium(name: leaders[2].name, pts: leaders[2].pts, rank: 3,
                       height: 85, color: Color(hex: 0xD89A72), crown: false, isMe: leaders[2].isMe)
            }
        }
        .frame(height: 200)
    }

    private var listCard: some View {
        let rest = Array(leaders.dropFirst(3))
        return VStack(spacing: 0) {
            ForEach(Array(rest.enumerated()), id: \.element.id) { idx, l in
                HStack(spacing: 12) {
                    Text("\(l.rank)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ink3)
                        .frame(width: 24, alignment: .center)
                    Avatar(initials: initials(for: l.name),
                           bg: l.isMe ? Color.coral : Color.ocean)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(l.name).font(.system(size: 14, weight: .semibold))
                        Text("\(l.tag) · \(l.area)")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.ink3)
                    }
                    Spacer()
                    Text(l.pts.formatted())
                        .font(.mono(13, weight: .semibold))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
                if idx < rest.count - 1 {
                    Color.hair.frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.hair, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    private var perks: some View {
        VStack(spacing: 6) {
            RankPerk(rank: "Top 1%", perk: "Seaside weekend giveaway entry", earned: true)
            RankPerk(rank: "Top 10%", perk: "2× sea bucks on weekends", earned: true)
            RankPerk(rank: "Top 25%", perk: "Early access to new rewards", earned: false)
        }
    }

    private func initials(for name: String) -> String {
        String(name.split(separator: " ").compactMap { $0.first }.prefix(2)).uppercased()
    }
}

private struct Podium: View {
    let name: String
    let pts: Int
    let rank: Int
    let height: CGFloat
    let color: Color
    let crown: Bool
    let isMe: Bool

    private var initials: String {
        String(name.split(separator: " ").compactMap { $0.first }.prefix(2)).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            if crown {
                Text("★")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: 0xC79A1E))
                    .padding(.bottom, 2)
            } else {
                Color.clear.frame(height: 20)
            }
            Avatar(initials: initials, bg: isMe ? Color.coral : color)
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .padding(.top, 6)
            Text(pts.formatted())
                .font(.mono(11))
                .foregroundStyle(Color.ink3)
                .padding(.bottom, 6)
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 8, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 8,
                    style: .continuous
                )
                .fill(color)
                .frame(height: height)
                Text("\(rank)")
                    .font(.serif(22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: 100)
    }
}

private struct RankPerk: View {
    let rank: String
    let perk: String
    let earned: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(earned ? Color.kelp : Color(hex: 0xF0EFE9))
                if earned {
                    IconCheck(size: 16).foregroundStyle(.white)
                } else {
                    IconShield(size: 16).foregroundStyle(Color.ink3)
                }
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(perk).font(.system(size: 13, weight: .semibold))
                Text("\(rank) · \(earned ? "Unlocked" : "Locked")")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ink3)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.hair, lineWidth: 1)
                )
        )
    }
}
