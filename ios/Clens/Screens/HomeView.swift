import SwiftUI

struct HomeView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var profileService: ProfileService
    @EnvironmentObject var ocean: OceanStressService
    @State private var posts: [SocialPost] = SocialPost.sample
    @State private var showBonusInfo = false

    private var seabucks: Int {
        profileService.balance
    }

    private var oceanPlainLanguage: String {
        let stress = ocean.stressIndex
        if stress >= 1.25 {
            return "Ocean conditions are stressed today — runoff-heavy picks (beef, dairy, processed) cost you more seabucks."
        }
        if stress >= 1.10 {
            return "Ocean conditions are slightly elevated — low-runoff produce earns a small bonus today."
        }
        return "Ocean conditions are calm today — scoring is close to baseline."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                screenHeader
                earnedTodayRow.padding(.horizontal, 20).padding(.top, 6)
                oceanHeroCard.padding(.horizontal, 16).padding(.top, 14)
                bonusNudgeRow.padding(.horizontal, 16).padding(.top, 10)
                friendsSection
            }
            .padding(.top, 24)
            .padding(.bottom, 96)
        }
        .background(Color.bg.ignoresSafeArea())
        .refreshable {
            if let userID = router.session?.userID {
                await profileService.load(userID: userID)
            }
        }
        .sheet(isPresented: $showBonusInfo) {
            BonusInfoSheet()
                .presentationDetents([.medium])
        }
    }

    // MARK: earned today — quick at-a-glance line

    private var earnedTodayRow: some View {
        HStack(spacing: 8) {
            IconWave(size: 14).foregroundStyle(Color.ocean)
            (Text("\(seabucks.formatted())").font(.system(size: 13, weight: .semibold))
             + Text(" seabucks · ").font(.system(size: 13))
             + Text("+\(Mock.receipt.earned) today").font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.kelp))
            .foregroundStyle(Color.ink2)
            Spacer(minLength: 0)
        }
    }

    // MARK: header

    private var screenHeader: some View {
        VStack(spacing: 14) {
            Text("Clens")
                .font(.serif(36))
                .padding(.top, 4)

            HStack(spacing: 8) {
                IconSearch(size: 16).foregroundStyle(Color.ink3)
                Text("Search products, receipts, friends")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.ink3)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.fill1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: ocean hero — Carbon + Ocean Combo

    private var oceanHeroCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: 0x0E6B96), Color(hex: 0x064A6B), Color(hex: 0x032A3D)],
                startPoint: .top, endPoint: .bottom
            )

            // Sun glint
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xFFDC78).opacity(0.55), .clear],
                        center: .center, startRadius: 0, endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .offset(x: 220, y: -60)

            WaveOverlay()

            // Dark bottom scrim so text stays readable
            LinearGradient(
                colors: [
                    Color(hex: 0x072E42).opacity(0.1),
                    Color(hex: 0x072E42).opacity(0.72),
                    Color(hex: 0x072E42).opacity(0.92),
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("TODAY · CCE2 MOORING")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer(minLength: 0)
                    stressBadge
                }

                Text("Carbon + Ocean Combo")
                    .font(.serif(28))
                    .foregroundStyle(.white)
                    .padding(.top, 4)

                Text(oceanPlainLanguage)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(2)
                    .padding(.top, 6)
            }
            .padding(18)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // Live stress readout — uses the value OceanScoreEngine actually scores
    // against, so the number in the hero card matches the runoff multiplier
    // applied to scans.
    private var stressBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stressColor)
                .frame(width: 6, height: 6)
            Text("STRESS \(String(format: "%.2f", ocean.stressIndex))")
                .font(.mono(10.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.12)))
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var stressColor: Color {
        let s = ocean.stressIndex
        if s >= 1.25 { return Color(hex: 0xE06B4A) }
        if s >= 1.10 { return Color(hex: 0xE6B548) }
        return Color(hex: 0x7FCFA8)
    }

    // MARK: 2× bonus nudge pill

    private var bonusNudgeRow: some View {
        HStack(spacing: 8) {
            Button { showBonusInfo = true } label: {
                HStack(spacing: 6) {
                    IconBolt(size: 12).foregroundStyle(Color(hex: 0xFFF7E8))
                    Text(Mock.oceanToday.alert)
                        .font(.system(size: 11.5, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color(hex: 0xFFF7E8))
                    IconChevR(size: 10).foregroundStyle(Color(hex: 0xFFF7E8).opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: 0x3F2E08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Learn about the 2× seabucks bonus")

            Text("· \(Mock.oceanToday.updated)")
                .font(.system(size: 12))
                .foregroundStyle(Color.ink3)
            Spacer(minLength: 0)
        }
    }

    // MARK: friends' scans — social feed

    private var friendsSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Friends' purchases")
            VStack(spacing: 12) {
                ForEach(posts) { post in
                    SocialPostCard(
                        post: post,
                        onLike: { toggleLike(post.id) },
                        onSave: { toggleSave(post.id) },
                        onOpen: { router.push(.scanResult(pid: post.pid)) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func toggleLike(_ id: Int) {
        guard let i = posts.firstIndex(where: { $0.id == id }) else { return }
        posts[i].liked.toggle()
        posts[i].likes += posts[i].liked ? 1 : -1
    }

    private func toggleSave(_ id: Int) {
        guard let i = posts.firstIndex(where: { $0.id == id }) else { return }
        posts[i].saved.toggle()
    }

}

// MARK: - Social feed

struct SocialPost: Identifiable {
    let id: Int
    let who: String
    let initials: String
    let avatarBg: Color
    let store: String
    let time: String
    let pid: String
    let productName: String
    let caption: String
    let score: Int
    var likes: Int
    var saves: Int
    var liked: Bool
    var saved: Bool

    static let sample: [SocialPost] = [
        SocialPost(
            id: 1, who: "Lauren Mongue", initials: "LM",
            avatarBg: Color.ocean,
            store: "Whole Foods Mar…", time: "2h ago",
            pid: "tofu", productName: "Organic Firm Tofu",
            caption: "Smart swap — full protein with a fraction of the footprint.",
            score: 82, likes: 31, saves: 4, liked: false, saved: false
        ),
        SocialPost(
            id: 2, who: "Noel at UTC", initials: "NS",
            avatarBg: Color.kelp,
            store: "Trader Joe's UTC", time: "5h ago",
            pid: "lentils", productName: "Green Lentils, Bulk",
            caption: "+58 extra seabucks — locally grown nitrogen-fixing crop hit today's 2× runoff bonus.",
            score: 94, likes: 58, saves: 12, liked: true, saved: false
        ),
    ]
}

private struct SocialPostCard: View {
    let post: SocialPost
    let onLike: () -> Void
    let onSave: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Avatar(initials: post.initials, bg: post.avatarBg)
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.who)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    Text("\(post.store) · \(post.time)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ink3)
                }
                Spacer(minLength: 0)
                Text("\(post.score)")
                    .font(.serif(14))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(scoreColor(post.score)))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // Product image
            Button(action: onOpen) {
                ZStack {
                    ProductThumb(
                        pid: post.pid,
                        size: 160,
                        imageURL: Mock.products[post.pid]?.imageURL
                    )
                    .frame(maxWidth: .infinity)
                    LinearGradient(
                        colors: [.black.opacity(0.0), .black.opacity(0.25)],
                        startPoint: .top, endPoint: .bottom
                    )
                    Text(post.productName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    Text(scoreLabel(post.score))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(scoreColor(post.score)))
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // Caption
            Text(post.caption)
                .font(.system(size: 13.5))
                .foregroundStyle(Color.ink)
                .lineSpacing(3)
                .padding(.horizontal, 14)
                .padding(.top, 10)

            // Engagement row
            HStack(spacing: 16) {
                Button(action: onLike) {
                    HStack(spacing: 5) {
                        Image(systemName: post.liked ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .regular))
                        Text("\(post.likes)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(post.liked ? Color.coral : Color.ink3)
                }
                .buttonStyle(.plain)

                Button(action: onSave) {
                    HStack(spacing: 5) {
                        Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 16, weight: .regular))
                        Text("\(post.saves)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(post.saved ? Color.ocean : Color.ink3)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onOpen) {
                    HStack(spacing: 4) {
                        Text("View product")
                            .font(.system(size: 12, weight: .semibold))
                        IconChevR(size: 14)
                    }
                    .foregroundStyle(Color.ocean)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.hair, lineWidth: 1)
                )
        )
    }
}

// MARK: - Bonus info sheet

private struct BonusInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("2× seabucks today")
                    .font(.serif(24))
                Spacer()
                Button { dismiss() } label: {
                    ZStack {
                        Circle().fill(Color.fill1).frame(width: 30, height: 30)
                        Text("✕").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ink2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.bottom, 6)

            Text("Low-runoff produce earns double seabucks while marine conditions are elevated.")
                .font(.system(size: 14))
                .foregroundStyle(Color.ink2)
                .lineSpacing(3)
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 12) {
                bullet("Leafy greens — spinach, kale, chard, romaine.")
                bullet("Root vegetables — carrots, beets, potatoes, onions.")
                bullet("Legumes — lentils, beans, chickpeas, peas.")
                bullet("Bonus doubles the seabucks for qualifying items until ocean stress normalizes.")
            }

            Spacer(minLength: 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bg.ignoresSafeArea())
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Color.kelp).frame(width: 6, height: 6).padding(.top, 7)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Color.ink)
                .lineSpacing(3)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Score → color / label (mirrors clens-screens.jsx)

private func scoreColor(_ s: Int) -> Color {
    if s >= 80 { return Color(hex: 0x3F7D58) }
    if s >= 60 { return Color(hex: 0x6B8A3A) }
    if s >= 40 { return Color(hex: 0xB58A20) }
    if s >= 20 { return Color(hex: 0xC7591A) }
    return Color(hex: 0xC7441F)
}

private func scoreLabel(_ s: Int) -> String {
    if s >= 85 { return "Excellent" }
    if s >= 65 { return "Good" }
    if s >= 45 { return "Fair" }
    if s >= 25 { return "Poor" }
    return "Very Poor"
}

