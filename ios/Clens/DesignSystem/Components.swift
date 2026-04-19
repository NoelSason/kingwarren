import SwiftUI

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
        ZStack {
            StripedFill(colors: seed)
            LinearGradient(
                colors: [Color.white.opacity(0.14), Color.black.opacity(0.2)],
                startPoint: .top, endPoint: .bottom
            )
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
                        .fill(Color(hex: 0xF0EFE9))
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
                        .fill(Color(hex: 0xF0EFE9))
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
