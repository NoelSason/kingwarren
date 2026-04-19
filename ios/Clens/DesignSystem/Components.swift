import SwiftUI
import UIKit
import Charts
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Code128 barcode renderer

struct BarcodeImage: View {
    let code: String
    var height: CGFloat = 70

    private static let context = CIContext()

    private var image: UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(code.utf8)
        filter.quietSpace = 7
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 3, y: 3))
        guard let cg = Self.context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.fill1)
                    .frame(height: height)
                    .overlay(Text("No code").font(.system(size: 11)).foregroundStyle(Color.ink3))
            }
        }
    }
}

// MARK: - Pill

struct Pill: View {
    let text: String
    var bg: Color = .sand
    var fg: Color = .ink

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(Capsule().fill(bg))
    }
}

// MARK: - Product thumbnail (striped placeholder)

struct ProductThumb: View {
    let pid: String
    var size: CGFloat = 56
    var imageURL: String? = nil

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

    private var placeholder: some View {
        ZStack {
            StripedFill(colors: seed)
            LinearGradient(
                colors: [Color.white.opacity(0.14), Color.black.opacity(0.2)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // Map pid → bundled asset name so hand-curated demo pics beat the
    // striped placeholder when OFF has no image URL.
    private var bundledAssetName: String? {
        switch pid {
        case "tofu":    return "Tofu"
        case "lentils": return "Lentils"
        default:        return nil
        }
    }

    private var hasBundledAsset: Bool {
        guard let name = bundledAssetName else { return false }
        return UIImage(named: name) != nil
    }

    var body: some View {
        Group {
            if let s = imageURL, let url = URL(string: s) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().padding(size * 0.05)
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder.overlay(ProgressView().tint(.white.opacity(0.7)))
                    @unknown default:
                        placeholder
                    }
                }
                .background(Color.white)
            } else if let name = bundledAssetName, hasBundledAsset {
                Image(name)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StripedFill: View {
    let colors: (Color, Color)
    var body: some View {
        Canvas { ctx, size in
            let stripe: CGFloat = 12
            let diag = (size.width + size.height) * 1.5
            ctx.translateBy(x: -size.width * 0.25, y: -size.height * 0.25)
            ctx.rotate(by: .degrees(45))
            var x: CGFloat = -diag
            var i = 0
            while x < diag {
                let c: Color = (i % 2 == 0) ? colors.0 : colors.1
                let rect = CGRect(x: x, y: -diag, width: stripe, height: diag * 2)
                ctx.fill(Path(rect), with: .color(c))
                x += stripe
                i += 1
            }
        }
    }
}

// MARK: - Striped placeholder for full imagery

struct PlaceholderBox: View {
    let label: String
    var height: CGFloat = 180
    var tone: Tone = .warm

    enum Tone { case warm, cool }

    private var seed: (Color, Color) {
        switch tone {
        case .warm: return (Color(hex: 0xE8DFC8), Color(hex: 0xDDD2B4))
        case .cool: return (Color(hex: 0xC9D6DB), Color(hex: 0xB2C3CA))
        }
    }

    var body: some View {
        ZStack {
            StripedFill(colors: seed)
            Text(label)
                .font(.mono(11))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: 0x6B6A60))
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.ink3)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ink3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

// MARK: - Avatar

struct Avatar: View {
    let initials: String
    var bg: Color = .ocean
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(bg)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.33, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - Feed card

struct FeedCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.hair, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Mini stat tile

struct MiniStat: View {
    let top: String
    let bot: String
    let foot: String
    let tone: Tone

    enum Tone { case good, mid, bad }

    private var color: Color {
        switch tone {
        case .good: return .kelp
        case .mid:  return Color(hex: 0xB58A20)
        case .bad:  return .coral
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(top).font(.serif(28))
            Text(bot)
                .font(.system(size: 12))
                .foregroundStyle(Color.ink2)
                .padding(.top, 4)
            Text(foot)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .padding(.top, 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.hair, lineWidth: 1)
                )
        )
    }
}

// MARK: - Hero stat (used inside dark gradient hero card)

struct HeroStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Facet bar (used in ScanResult)

struct Facet: View {
    let icon: AnyView
    let name: String
    let value: Int
    let sub: String
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.fill1)
                        .frame(width: 36, height: 36)
                    icon
                        .foregroundStyle(Color.ink2)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 14, weight: .semibold))
                    Text(sub).font(.system(size: 12)).foregroundStyle(Color.ink3)
                }
                Spacer()
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.fill1)
                        .frame(width: 96, height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Score.color(value))
                        .frame(width: max(2, 96 * CGFloat(value) / 100), height: 6)
                }
                Text("\(value)")
                    .font(.mono(11))
                    .foregroundStyle(Color.ink2)
                    .frame(width: 28, alignment: .trailing)
            }
            .padding(.vertical, 14)
            if !isLast {
                Color.hair.frame(height: 1)
            }
        }
    }
}

// MARK: - Origin charts card (replaces PlaceholderBox in ScanResultView)

struct OriginChartsCard: View {
    @EnvironmentObject var ocean: OceanStressService
    @EnvironmentObject var history: ScanHistoryStore

    var body: some View {
        VStack(spacing: 12) {
            stressPanel
            scoresPanel
        }
        .padding(.horizontal, 16)
    }

    // MARK: Panel A — regional stress time series
    private var stressPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("REGIONAL OCEAN STRESS · CCE2")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.oceanCardText.opacity(0.8))
                Spacer()
                Text(String(format: "now %.2f×", ocean.stressIndex))
                    .font(.mono(10, weight: .semibold))
                    .foregroundStyle(Color.oceanCardText)
            }

            Chart {
                ForEach(stressSeries, id: \.date) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("Stress", pt.value)
                    )
                    .foregroundStyle(Color.ocean)
                    .interpolationMethod(.catmullRom)
                }
                RuleMark(y: .value("Normal", 1.0))
                    .foregroundStyle(Color.oceanCardText.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Text("normal")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.oceanCardText.opacity(0.6))
                            .padding(.trailing, 4)
                    }
            }
            .chartYScale(domain: 0...2)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(Color.oceanCardText.opacity(0.7))
                    AxisGridLine().foregroundStyle(Color.oceanCardText.opacity(0.12))
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 1, 2]) {
                    AxisValueLabel().foregroundStyle(Color.oceanCardText.opacity(0.7))
                    AxisGridLine().foregroundStyle(Color.oceanCardText.opacity(0.12))
                }
            }
            .frame(height: 130)

            Text("modeled demo series · actual stress adjusts today's score only")
                .font(.system(size: 10))
                .foregroundStyle(Color.oceanCardText.opacity(0.55))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.oceanCardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.oceanCardStroke, lineWidth: 1)
                )
        )
    }

    // MARK: Panel B — recent scan scores
    private var scoresPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("RECENT SCANS · GREEN SCORE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.ink3)
                Spacer()
                Text("\(scoreRows.count) items")
                    .font(.mono(10, weight: .semibold))
                    .foregroundStyle(Color.ink3)
            }

            Chart(scoreRows) { row in
                BarMark(
                    x: .value("Score", row.score),
                    y: .value("Product", row.name)
                )
                .foregroundStyle(Score.color(row.score))
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text("\(row.score)")
                        .font(.mono(10))
                        .foregroundStyle(Color.ink2)
                }
            }
            .chartXScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: [0, 50, 100]) {
                    AxisValueLabel().foregroundStyle(Color.ink3)
                    AxisGridLine().foregroundStyle(Color.hair)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color.ink2)
                }
            }
            .frame(height: CGFloat(max(140, scoreRows.count * 22 + 10)))
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

    // MARK: - Data

    private struct StressPoint { let date: Date; let value: Double }
    private struct ScoreRow: Identifiable {
        let id = UUID()
        let name: String
        let score: Int
    }

    // Synthesize ~90 days of stress, ending at today's current value. Purely
    // cosmetic — mirrors the shape of the reference chart so the panel feels
    // alive during the demo. Scoring does not read this series.
    private var stressSeries: [StressPoint] {
        let days = 90
        let now = Date()
        let cal = Calendar.current
        let current = ocean.stressIndex
        var rng = SeededRNG(seed: 0x0CE4)
        return (0..<days).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: now) ?? now
            // Seasonal sine (weekly period to look textured), plus noise, pulled
            // toward `current` at the right edge so it lands on today's value.
            let t = Double(days - offset) / Double(days)
            let season = 0.55 * sin(Double(days - offset) * .pi / 10)
            let drift = 0.35 * sin(Double(days - offset) * .pi / 42)
            let noise = rng.next() * 0.25 - 0.125
            let base = 1.0 + season + drift + noise
            let pulled = base * (1 - t) + current * t
            return StressPoint(date: date, value: max(0, min(2, pulled)))
        }
    }

    private var scoreRows: [ScoreRow] {
        let recent = history.records.prefix(10)
        if recent.isEmpty {
            return Mock.products.values
                .sorted { $0.score > $1.score }
                .prefix(8)
                .map { ScoreRow(name: $0.name, score: $0.score) }
        }
        var seen = Set<String>()
        var rows: [ScoreRow] = []
        for r in recent {
            guard !seen.contains(r.productName) else { continue }
            seen.insert(r.productName)
            rows.append(ScoreRow(name: r.productName, score: r.score))
        }
        return rows
    }
}

// Tiny deterministic PRNG so the stress line is stable across renders.
private struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { self.state = seed | 1 }
    mutating func next() -> Double {
        state &*= 6364136223846793005
        state &+= 1442695040888963407
        let x = Double((state >> 33) & 0xFFFFFFFF) / Double(UInt32.max)
        return x
    }
}

// MARK: - Wave background overlay (for hero card)

struct WaveOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            var path1 = Path()
            path1.move(to: CGPoint(x: 0, y: h * 0.65))
            path1.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.65),
                               control: CGPoint(x: w * 0.25, y: h * 0.5))
            path1.addQuadCurve(to: CGPoint(x: w, y: h * 0.65),
                               control: CGPoint(x: w * 0.75, y: h * 0.8))
            path1.addLine(to: CGPoint(x: w, y: h))
            path1.addLine(to: CGPoint(x: 0, y: h))
            path1.closeSubpath()
            ctx.fill(path1, with: .color(.white.opacity(0.12)))

            var path2 = Path()
            path2.move(to: CGPoint(x: 0, y: h * 0.78))
            path2.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.78),
                               control: CGPoint(x: w * 0.25, y: h * 0.65))
            path2.addQuadCurve(to: CGPoint(x: w, y: h * 0.78),
                               control: CGPoint(x: w * 0.75, y: h * 0.92))
            path2.addLine(to: CGPoint(x: w, y: h))
            path2.addLine(to: CGPoint(x: 0, y: h))
            path2.closeSubpath()
            ctx.fill(path2, with: .color(.white.opacity(0.07)))
        }
        .allowsHitTesting(false)
    }
}
