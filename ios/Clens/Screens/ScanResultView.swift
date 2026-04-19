import SwiftUI

struct ScanResultView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var coordinator: ScanCoordinator
    let pid: String

    private var product: Product? {
        coordinator.product(for: pid) ?? Mock.products[pid]
    }

    var body: some View {
        if let p = product {
            content(p)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func content(_ p: Product) -> some View {
        let color = Score.color(p.score)
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                hero(p, color: color)
                Spacer().frame(height: 52)

                VStack(spacing: 4) {
                    Text(p.brand.uppercased())
                        .font(.system(size: 11, weight: .regular))
                        .tracking(1.5)
                        .foregroundStyle(Color.ink3)
                    Text(p.name)
                        .font(.serif(26))
                        .multilineTextAlignment(.center)
                    Text("\(p.size) · \(p.category)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.ink2)
                }
                .padding(.horizontal, 20)

                scoreCard(p, color: color)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                SectionHeader(title: "Impact breakdown")
                breakdownCard(p)

                oceanModifier
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                SectionHeader(title: "Known facts")
                factsList(p)

                if let _ = Mock.swaps[pid] {
                    SectionHeader(title: "What if you...")
                    swapCTA(p)
                }

                SectionHeader(title: "Origin")
                PlaceholderBox(label: "[ origin map · \(p.origin) ]", height: 120, tone: .cool)
                    .padding(.horizontal, 16)

                Spacer().frame(height: 30)
            }
            .padding(.bottom, 110)
        }
        .background(Color.bg.ignoresSafeArea())
    }

    private func hero(_ p: Product, color: Color) -> some View {
        ZStack {
            LinearGradient(colors: [color.opacity(0.15), .clear],
                           startPoint: .top, endPoint: .bottom)
            VStack {
                HStack {
                    Button { router.pop() } label: {
                        ZStack {
                            Circle().fill(.white.opacity(0.8))
                            IconChevL(size: 18)
                        }
                        .frame(width: 36, height: 36)
                    }
                    Spacer()
                    Button { router.pop() } label: {
                        Text("Save")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(Capsule().fill(.white.opacity(0.8)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 50)
                Spacer()
            }
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.hair, lineWidth: 1)
                        )
                        .frame(width: 140, height: 180)
                    ProductThumb(pid: p.id, size: 120)
                }
                .offset(y: 40)
            }
        }
        .frame(height: 220)
    }

    private func scoreCard(_ p: Product, color: Color) -> some View {
        HStack(spacing: 16) {
            ScoreDial(score: p.score, size: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text("OCEAN SCORE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.ink3)
                Text(Score.label(p.score))
                    .font(.serif(22))
                    .foregroundStyle(color)
                (Text("Earns ").font(.system(size: 12.5))
                 + Text("\(Int(Double(p.score) * 1.6)) pts").font(.system(size: 12.5, weight: .bold))
                 + Text(" at checkout.").font(.system(size: 12.5)))
                    .foregroundStyle(Color.ink2)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.hair, lineWidth: 1)
                )
        )
    }

    private func breakdownCard(_ p: Product) -> some View {
        VStack(spacing: 0) {
            Facet(icon: AnyView(IconFactory(size: 18)),
                  name: "Climate", value: p.breakdown.climate, sub: "CO\u{2082} per kg produced")
            Facet(icon: AnyView(IconWave(size: 18)),
                  name: "Runoff", value: p.breakdown.runoff, sub: "Fertilizer → ocean")
            Facet(icon: AnyView(IconBox(size: 18)),
                  name: "Plastic", value: p.breakdown.plastic, sub: "Packaging + supply chain")
            Facet(icon: AnyView(IconDroplet(size: 18)),
                  name: "Water", value: p.breakdown.water, sub: "L per kg produced", isLast: true)
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

    private var oceanModifier: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.ocean)
                IconWave(size: 16).foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("LIVE OCEAN MODIFIER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.oceanInk)
                (Text("Stress index ").font(.system(size: 13))
                 + Text(String(format: "%.2f×", Mock.oceanToday.stressIndex))
                    .font(.system(size: 13, weight: .bold))
                 + Text(" today — runoff-heavy items lose 18 pts vs baseline.")
                    .font(.system(size: 13)))
                    .foregroundStyle(Color.oceanInk)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0xEAF4F7))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: 0xBFD9E0), lineWidth: 1)
                )
        )
    }

    private func factsList(_ p: Product) -> some View {
        VStack(spacing: 6) {
            ForEach(p.facts, id: \.self) { f in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Color.ink).frame(width: 6, height: 6).padding(.top, 6)
                    Text(f).font(.system(size: 13)).foregroundStyle(Color.ink)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
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
        .padding(.horizontal, 16)
    }

    private func swapCTA(_ p: Product) -> some View {
        let swap = Mock.swaps[pid]!
        return Button {
            router.push(.swap(pid: pid))
        } label: {
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    ProductThumb(pid: pid, size: 42)
                    IconSwap(size: 16).foregroundStyle(.white.opacity(0.6))
                    ProductThumb(pid: swap.to, size: 42)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("SWAP TO")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(swap.altName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("+\(swap.deltaPoints) pts · +\(swap.deltaScore) score")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFFB89F))
                }
                Spacer()
                IconChevR(size: 18).foregroundStyle(.white)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.ink)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}
