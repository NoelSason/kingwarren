import SwiftUI

struct HomeView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                screenHeader
                heroHaulCard.padding(.horizontal, 16).padding(.top, 6)
                oceanAlert.padding(.horizontal, 16).padding(.top, 14)
                weekSection
                whatIfSection
                activitySection
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
                    .fill(Color(hex: 0xF0EFE9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: hero

    private var heroHaulCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.ocean, Color.oceanInk],
                startPoint: .top, endPoint: .bottom
            )
            WaveOverlay()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TODAY'S HAUL")
                            .font(.system(size: 11, weight: .regular))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Warren earned")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 4)
                        Text("+431")
                            .font(.serif(52))
                            .foregroundStyle(.white)
                            .padding(.top, 4)
                        Text("sea bucks at Whole Foods Market")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    ScoreDial(score: 64, size: 88, stroke: 8, showLabel: false)
                        .colorScheme(.dark)
                        .environment(\.colorScheme, .dark)
                }

                Color.white.opacity(0.15).frame(height: 1).padding(.top, 14)

                HStack(spacing: 14) {
                    HeroStat(label: "CO\u{2082} saved", value: "4.2 kg")
                    HeroStat(label: "Plastic", value: "−38 g")
                    HeroStat(label: "Water", value: "−210 L")
                }
                .padding(.top, 12)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: ocean alert banner

    private var oceanAlert: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5D98B))
                IconWave(size: 18)
                    .foregroundStyle(Color(hex: 0x7A5B10))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("OCEAN ALERT")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color(hex: 0x7A5B10))
                    Text("· \(Mock.oceanToday.updated)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0x7A5B10).opacity(0.7))
                }
                Text(Mock.oceanToday.headline)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x3F2E08))
                Text(Mock.oceanToday.detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color(hex: 0x5C4612))
                    .lineSpacing(2)
                    .padding(.top, 2)

                HStack(spacing: 6) {
                    IconBolt(size: 11).foregroundStyle(Color(hex: 0xFFF7E8))
                    Text(Mock.oceanToday.alert)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color(hex: 0xFFF7E8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: 0x3F2E08)))
                .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0xFFF7E8))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: 0xEDD59D), lineWidth: 1)
                )
        )
    }

    // MARK: week stats

    private var weekSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "This week", trailing: "184,240 sea bucks earned nearby")
            HStack(spacing: 10) {
                MiniStat(top: "+1,284", bot: "pts this week", foot: "+18% vs last", tone: .good)
                MiniStat(top: "64", bot: "avg ocean score", foot: "Fair", tone: .mid)
            }
            .padding(.horizontal, 16)
        }
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
                        ProductThumb(pid: "beef", size: 52)
                        IconSwap(size: 14).foregroundStyle(Color.ink3)
                        ProductThumb(pid: "lentils", size: 52)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("+220 PTS MISSED")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.coral)
                        Text("Swap beef → lentils to catch the 2× runoff bonus")
                            .font(.system(size: 14, weight: .semibold))
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

    // MARK: activity

    private var activitySection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Activity")
            VStack(spacing: 8) {
                FeedCard {
                    HStack(alignment: .top, spacing: 12) {
                        Avatar(initials: "AS", bg: Color.kelp)
                        VStack(alignment: .leading, spacing: 2) {
                            (Text("Aarav").font(.system(size: 13.5, weight: .bold))
                             + Text(" overtook you on the weekly board").font(.system(size: 13.5)))
                                .foregroundStyle(Color.ink)
                            Text("+112 ahead · scan a receipt to catch up")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.ink2)
                            Text("1h ago")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.ink3)
                                .padding(.top, 2)
                        }
                        Spacer(minLength: 0)
                    }
                }
                FeedCard {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xE8F0EE))
                            IconLeaf(size: 18).foregroundStyle(Color.kelp)
                        }
                        .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            (Text("Your lifetime impact crossed ").font(.system(size: 13.5))
                             + Text("184 kg CO\u{2082} avoided").font(.system(size: 13.5, weight: .bold)))
                                .foregroundStyle(Color.ink)
                            Text("That's ~460 miles of driving, not driven.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.ink2)
                            Text("Yesterday")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.ink3)
                                .padding(.top, 2)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
