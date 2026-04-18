import SwiftUI

struct ReceiptResultView: View {
    @EnvironmentObject var router: AppRouter
    @State private var parsing: Bool = true
    @State private var spin: Bool = false

    private var receipt: Receipt { Mock.receipt }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topBar.padding(.horizontal, 16).padding(.top, 50)

                if parsing {
                    parsingState
                } else {
                    storeHeader
                    summaryCard.padding(.horizontal, 16).padding(.top, 14)

                    SectionHeader(title: "Items & scores", trailing: "Tap any item")
                    itemsCard

                    SectionHeader(title: "What if you swapped...", trailing: "+304 possible")
                    swapsList

                    Spacer().frame(height: 30)
                }
            }
            .padding(.bottom, 110)
        }
        .background(Color.bg.ignoresSafeArea())
        .onAppear {
            spin = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.25)) { parsing = false }
            }
        }
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
            Pill(text: "Receipt")
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var parsingState: some View {
        VStack(spacing: 0) {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.ocean, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: spin)
            Text("Reading receipt…")
                .font(.system(size: 14))
                .foregroundStyle(Color.ink2)
                .padding(.top, 20)
            Text("OCR · classifier · OpenFoodFacts · impact lookup")
                .font(.mono(11))
                .foregroundStyle(Color.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .padding(.horizontal, 30)
    }

    private var storeHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(receipt.date.uppercased())
                .font(.system(size: 11, weight: .regular))
                .tracking(1.5)
                .foregroundStyle(Color.ink3)
            Text(receipt.store)
                .font(.serif(26))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var summaryCard: some View {
        HStack(spacing: 20) {
            ScoreDial(score: receipt.averageScore, size: 84, stroke: 8, showLabel: false)
                .colorScheme(.dark)
                .environment(\.colorScheme, .dark)
            VStack(alignment: .leading, spacing: 2) {
                Text("YOU EARNED")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.7))
                Text("+\(receipt.earned)")
                    .font(.serif(42))
                    .foregroundStyle(.white)
                Text("sea bucks · \(receipt.items.count) items · $\(String(format: "%.2f", receipt.total))")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color.ocean, Color.oceanInk],
                                     startPoint: .top, endPoint: .bottom))
        )
    }

    private var itemsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(receipt.items.enumerated()), id: \.element.id) { idx, item in
                let product = Mock.products[item.pid]
                Button {
                    router.push(.scanResult(pid: item.pid))
                } label: {
                    HStack(spacing: 12) {
                        ProductThumb(pid: item.pid, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 13.5, weight: .semibold))
                                .lineLimit(1)
                                .foregroundStyle(Color.ink)
                            Text("$\(String(format: "%.2f", item.price)) · \(product?.category.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? "")")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Color.ink3)
                        }
                        Spacer()
                        if let p = product {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("\(p.score)")
                                    .font(.serif(16))
                                    .foregroundStyle(Score.color(p.score))
                                Text(Score.label(p.score).uppercased())
                                    .font(.system(size: 10))
                                    .tracking(0.5)
                                    .foregroundStyle(Color.ink3)
                            }
                        }
                        IconChevR(size: 14).foregroundStyle(Color.ink3)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
                if idx < receipt.items.count - 1 {
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

    private var swapsList: some View {
        VStack(spacing: 8) {
            SwapMini(pid: "beef")
            SwapMini(pid: "monster")
        }
        .padding(.horizontal, 16)
    }
}

private struct SwapMini: View {
    @EnvironmentObject var router: AppRouter
    let pid: String

    var body: some View {
        if let swap = Mock.swaps[pid],
           let from = Mock.products[pid],
           let to = Mock.products[swap.to] {
            Button {
                router.push(.swap(pid: pid))
            } label: {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        ProductThumb(pid: from.id, size: 40)
                        IconSwap(size: 14).foregroundStyle(Color.ink3)
                        ProductThumb(pid: to.id, size: 40)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(from.name) → \(to.name.split(separator: ",").first.map(String.init) ?? to.name)")
                            .font(.system(size: 13, weight: .semibold))
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(Color.ink)
                            .lineSpacing(1)
                        Text("+\(swap.deltaPoints) pts · +\(swap.deltaScore) score")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Color.kelp)
                    }
                    Spacer()
                    IconChevR(size: 14).foregroundStyle(Color.ink3)
                }
                .padding(12)
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
        }
    }
}
