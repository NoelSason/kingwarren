import SwiftUI

struct SwapView: View {
    @EnvironmentObject var router: AppRouter
    let pid: String

    private var swap: Swap? { Mock.swaps[pid] }
    private var from: Product? { Mock.products[pid] }
    private var to: Product? { swap.flatMap { Mock.products[$0.to] } }

    var body: some View {
        if let swap, let from, let to {
            content(swap: swap, from: from, to: to)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func content(swap: Swap, from: Product, to: Product) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topBar.padding(.horizontal, 16).padding(.top, 50)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trade this for that.")
                        .font(.serif(30))
                    Text("Here's what you'd gain if you swapped one item from today's haul.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ink2)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

                compareCard(from: from, to: to).padding(.horizontal, 16).padding(.top, 8)

                deltaCard(swap: swap).padding(.horizontal, 16).padding(.top, 14)

                SectionHeader(title: "Why it's better")
                prosList(swap.pros)

                SectionHeader(title: "Trade-offs")
                consList(swap.cons)

                bottomActions.padding(.horizontal, 16).padding(.top, 22)

                Spacer().frame(height: 30)
            }
            .padding(.bottom, 110)
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
            Pill(text: "What-if", bg: Color.ink, fg: .white)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private func compareCard(from: Product, to: Product) -> some View {
        VStack(spacing: 0) {
            CompareRow(product: from, tone: .bad)
            HStack {
                IconChevD(size: 14).foregroundStyle(Color.ink2)
                Text("SWAP TO")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.ink2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(
                LinearGradient(
                    colors: [Color.coral.opacity(0.08), Color.kelp.opacity(0.08)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            CompareRow(product: to, tone: .good)
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.hair, lineWidth: 1)
        )
    }

    private func deltaCard(swap: Swap) -> some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.6))
                Text("+\(swap.deltaScore)")
                    .font(.serif(40))
                    .foregroundStyle(Color(hex: 0x9BD4AF))
            }
            Color.white.opacity(0.2).frame(width: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("SEA BUCKS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.6))
                Text("+\(swap.deltaPoints)")
                    .font(.serif(40))
                    .foregroundStyle(Color(hex: 0xFFB89F))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.ink)
        )
    }

    private func prosList(_ items: [String]) -> some View {
        VStack(spacing: 6) {
            ForEach(items, id: \.self) { x in
                HStack(alignment: .top, spacing: 10) {
                    IconCheck(size: 18).foregroundStyle(Color.kelp)
                    Text(x).font(.system(size: 13))
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

    private func consList(_ items: [String]) -> some View {
        VStack(spacing: 6) {
            ForEach(items, id: \.self) { x in
                HStack(alignment: .top, spacing: 10) {
                    IconInfo(size: 18).foregroundStyle(Color.ink3)
                    Text(x).font(.system(size: 13))
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

    private var bottomActions: some View {
        VStack(spacing: 8) {
            Button { router.reset() } label: {
                Text("Add to next-shop list")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.kelp))
            }
            Button { router.pop() } label: {
                Text("No thanks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.ink2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
    }
}

private struct CompareRow: View {
    enum Tone { case good, bad }
    let product: Product
    let tone: Tone

    var body: some View {
        HStack(spacing: 14) {
            ProductThumb(pid: product.id, size: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.system(size: 14, weight: .semibold))
                Text("\(product.brand) · \(product.size)")
                    .font(.system(size: 12)).foregroundStyle(Color.ink3)
                HStack(spacing: 6) {
                    Circle().fill(tone == .good ? Color.kelp : Color.coral).frame(width: 8, height: 8)
                    Text(Score.label(product.score))
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.top, 4)
            }
            Spacer()
            ScoreDial(score: product.score, size: 56, stroke: 6, showLabel: false)
        }
        .padding(14)
    }
}
