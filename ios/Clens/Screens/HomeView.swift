import SwiftUI

struct HomeView: View {
    @EnvironmentObject var router: AppRouter
    @State private var posts: [SocialPost] = SocialPost.sample

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                screenHeader
                oceanHeroCard.padding(.horizontal, 16).padding(.top, 6)
                bonusNudgeRow.padding(.horizontal, 16).padding(.top, 10)
                friendsSection
                whatIfSection
                Spacer().frame(height: 40)
            }
            .padding(.top, 50)
            .padding(.bottom, 110)
        }
        .background(Color.bg.ignoresSafeArea())
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
                Text("TODAY · CCE2 MOORING")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.75))

                Text("Carbon + Ocean Combo")
                    .font(.serif(28))
                    .foregroundStyle(.white)
                    .padding(.top, 4)

                Text(String(format: "Your lifestyle after ocean scoring — runoff-heavy picks penalized %.2f×", Mock.oceanToday.stressIndex))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineSpacing(2)
                    .padding(.top, 5)

                HStack(spacing: 8) {
                    OceanChip(label: "pH \(Mock.oceanToday.pH)")
                    OceanChip(label: "O\u{2082} \(Mock.oceanToday.dissolvedO2)")
                    OceanChip(label: "Chl \(Mock.oceanToday.chlorophyll)")
                }
                .padding(.top, 12)
            }
            .padding(18)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: 2× bonus nudge pill

    private var bonusNudgeRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                IconBolt(size: 12).foregroundStyle(Color(hex: 0xFFF7E8))
                Text(Mock.oceanToday.alert)
                    .font(.system(size: 11.5, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Color(hex: 0xFFF7E8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(hex: 0x3F2E08)))

            Text("· \(Mock.oceanToday.updated)")
                .font(.system(size: 12))
                .foregroundStyle(Color.ink3)
            Spacer(minLength: 0)
        }
    }

    // MARK: friends' scans — social feed

    private var friendsSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Friends' scans")
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

    // MARK: what-if

    private var whatIfSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "What if you had...")
            Button {
                router.push(.swap(pid: "beef"))
            } label: {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        ProductThumb(pid: "beef", size: 48)
                        IconSwap(size: 14).foregroundStyle(Color.ink3)
                        ProductThumb(pid: "lentils", size: 48)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("+220 PTS MISSED")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.coral)
                        Text("Swap beef → lentils to catch the 2× runoff bonus")
                            .font(.system(size: 13.5, weight: .semibold))
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(Color.ink)
                            .lineSpacing(1)
                        Text("Direct hit on today's algal bloom driver.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.ink2)
                    }
                    Spacer(minLength: 0)
                    IconChevR(size: 18).foregroundStyle(Color.ink3)
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
            .padding(.horizontal, 16)
        }
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
            caption: "+State – Smart pick. Green beef, meet full protein with less footprint.",
            score: 82, likes: 31, saves: 4, liked: false, saved: false
        ),
        SocialPost(
            id: 2, who: "Noel at UTC", initials: "NS",
            avatarBg: Color.kelp,
            store: "Trader Joe's UTC", time: "5h ago",
            pid: "lentils", productName: "Green Lentils, Bulk",
            caption: "Loves: +58 extra bucks – Locally grown nitrogen-fixing crop hit today's 2× runoff bonus.",
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

            // Product image strip
            Button(action: onOpen) {
                ZStack {
                    PostStripe(pid: post.pid)
                    LinearGradient(
                        colors: [.white.opacity(0.05), .black.opacity(0.3)],
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

// MARK: - Full-width diagonal-stripe banner (keyed off product id)

private struct PostStripe: View {
    let pid: String

    private var seed: (Color, Color) {
        switch pid {
        case "monster": return (Color(hex: 0x0E2216), Color(hex: 0x3A5A40))
        case "avocado": return (Color(hex: 0x4F6F3B), Color(hex: 0x87A97A))
        case "beef":    return (Color(hex: 0x6B2D1F), Color(hex: 0xA14B35))
        case "oats":    return (Color(hex: 0xBFA67A), Color(hex: 0xE5D8B5))
        case "lentils": return (Color(hex: 0x5B6E3A), Color(hex: 0x8FA75E))
        case "tofu":    return (Color(hex: 0xE8E2CC), Color(hex: 0xB9B08A))
        default:        return (Color(hex: 0xCCCCCC), Color(hex: 0xEEEEEE))
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let stripe: CGFloat = 12
            let diag = (size.width + size.height) * 1.5
            ctx.translateBy(x: -size.width * 0.25, y: -size.height * 0.25)
            ctx.rotate(by: .degrees(45))
            var x: CGFloat = -diag
            var i = 0
            while x < diag {
                let c: Color = (i % 2 == 0) ? seed.0 : seed.1
                let rect = CGRect(x: x, y: -diag, width: stripe, height: diag * 2)
                ctx.fill(Path(rect), with: .color(c))
                x += stripe
                i += 1
            }
        }
    }
}

// MARK: - Ocean conditions chip (frosted)

private struct OceanChip: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.3)
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.18)))
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

