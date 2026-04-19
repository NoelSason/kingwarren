import SwiftUI

struct ReceiptResultView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var coordinator: ScanCoordinator
    @State private var parsing: Bool = true
    @State private var spin: Bool = false

    private var receipt: Receipt { coordinator.liveReceipt ?? Mock.receipt }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topBar.padding(.horizontal, 16).padding(.top, 24)

                if parsing {
                    parsingState
                } else {
                    storeHeader
                    summaryCard.padding(.horizontal, 16).padding(.top, 14)

                    SectionHeader(title: "Items & scores", trailing: "Tap any item")
                    itemsCard

                    if !receipt.swaps.isEmpty {
                        SectionHeader(
                            title: "What if you swapped...",
                            trailing: swapsHeaderTrailing
                        )
                        swapsList
                    }

                }
            }
            .padding(.bottom, 96)
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
                Text("seabucks · \(receipt.items.count) items · $\(String(format: "%.2f", receipt.total))")
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
                let product = coordinator.product(for: item.pid) ?? Mock.products[item.pid]
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
            ForEach(receipt.swaps) { swap in
                SwapRow(swap: swap)
            }
        }
        .padding(.horizontal, 16)
    }

    private var swapsHeaderTrailing: String {
        let total = receipt.swaps.map { max(0, $0.deltaPoints) }.reduce(0, +)
        return "+\(total) seabucks possible"
    }
}

private struct SwapRow: View {
    let swap: ReceiptSwap

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                (
                    Text(swap.fromName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.ink)
                    + Text("  ⇄  ")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.ink3)
                    + Text(swap.toName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.ink)
                )
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Text(swap.rationale)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.ink3)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(deltaLabel)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(deltaColor)
            }
            Spacer(minLength: 8)
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

    private var deltaLabel: String {
        let pts = swap.deltaPoints
        let score = swap.deltaScore
        let ptsSign = pts >= 0 ? "+" : ""
        let scoreSign = score >= 0 ? "+" : ""
        return "\(ptsSign)\(pts) seabucks · \(scoreSign)\(score) green score"
    }

    private var deltaColor: Color {
        swap.deltaPoints >= 0 ? Color.kelp : Color.ink3
    }
}
