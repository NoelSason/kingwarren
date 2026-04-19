import SwiftUI

// 24×24 line icons, stroke 1.75, rounded — match the JSX `Icon` component.
// Color via .foregroundStyle (uses currentColor).

struct LineIcon: View {
    var size: CGFloat = 24
    var stroke: CGFloat = 1.75
    let path: @Sendable (inout Path) -> Void

    var body: some View {
        IconShape(builder: path)
            .stroke(style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

private struct IconShape: Shape {
    let builder: @Sendable (inout Path) -> Void
    func path(in rect: CGRect) -> Path {
        var p = Path()
        builder(&p)
        let scale = rect.width / 24
        return p.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}

// Helper to keep call sites short
private func icon(_ size: CGFloat = 24, _ build: @escaping @Sendable (inout Path) -> Void) -> some View {
    LineIcon(size: size, path: build)
}

struct IconHome: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 3, y: 10.5))
            p.addLine(to: CGPoint(x: 12, y: 3))
            p.addLine(to: CGPoint(x: 21, y: 10.5))
            p.addLine(to: CGPoint(x: 21, y: 20))
            p.addLine(to: CGPoint(x: 15, y: 20))
            p.addLine(to: CGPoint(x: 15, y: 13))
            p.addLine(to: CGPoint(x: 9, y: 13))
            p.addLine(to: CGPoint(x: 9, y: 20))
            p.addLine(to: CGPoint(x: 3, y: 20))
            p.closeSubpath()
        }
    }
}

struct IconGift: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            // Box body
            p.move(to: CGPoint(x: 4, y: 12))
            p.addLine(to: CGPoint(x: 4, y: 20))
            p.addLine(to: CGPoint(x: 20, y: 20))
            p.addLine(to: CGPoint(x: 20, y: 12))
            // Top
            p.move(to: CGPoint(x: 2, y: 7))
            p.addLine(to: CGPoint(x: 22, y: 7))
            p.addLine(to: CGPoint(x: 22, y: 12))
            p.addLine(to: CGPoint(x: 2, y: 12))
            p.closeSubpath()
            // Vertical ribbon
            p.move(to: CGPoint(x: 12, y: 22))
            p.addLine(to: CGPoint(x: 12, y: 7))
            // Bow
            p.move(to: CGPoint(x: 12, y: 7))
            p.addCurve(to: CGPoint(x: 7.5, y: 2),
                       control1: CGPoint(x: 10, y: 5), control2: CGPoint(x: 9, y: 2))
            p.move(to: CGPoint(x: 12, y: 7))
            p.addCurve(to: CGPoint(x: 16.5, y: 2),
                       control1: CGPoint(x: 14, y: 5), control2: CGPoint(x: 15, y: 2))
        }
    }
}

struct IconTrophy: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 8, y: 21))
            p.addLine(to: CGPoint(x: 16, y: 21))
            p.move(to: CGPoint(x: 12, y: 17))
            p.addLine(to: CGPoint(x: 12, y: 21))
            // Cup body
            p.move(to: CGPoint(x: 7, y: 4))
            p.addLine(to: CGPoint(x: 17, y: 4))
            p.addLine(to: CGPoint(x: 17, y: 8))
            p.addCurve(to: CGPoint(x: 7, y: 8),
                       control1: CGPoint(x: 17, y: 11), control2: CGPoint(x: 7, y: 11))
            p.closeSubpath()
            // Side handles
            p.move(to: CGPoint(x: 17, y: 5))
            p.addLine(to: CGPoint(x: 20, y: 5))
            p.addLine(to: CGPoint(x: 20, y: 7))
            p.addCurve(to: CGPoint(x: 17, y: 10),
                       control1: CGPoint(x: 20, y: 9), control2: CGPoint(x: 18.5, y: 10))
            p.move(to: CGPoint(x: 7, y: 5))
            p.addLine(to: CGPoint(x: 4, y: 5))
            p.addLine(to: CGPoint(x: 4, y: 7))
            p.addCurve(to: CGPoint(x: 7, y: 10),
                       control1: CGPoint(x: 4, y: 9), control2: CGPoint(x: 5.5, y: 10))
        }
    }
}

struct IconUser: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.addEllipse(in: CGRect(x: 8, y: 4, width: 8, height: 8))
            p.move(to: CGPoint(x: 4, y: 21))
            p.addCurve(to: CGPoint(x: 20, y: 21),
                       control1: CGPoint(x: 4, y: 16.6), control2: CGPoint(x: 12, y: 13))
        }
    }
}

struct IconScan: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            // Top-left bracket
            p.move(to: CGPoint(x: 3, y: 8))
            p.addLine(to: CGPoint(x: 3, y: 5))
            p.addQuadCurve(to: CGPoint(x: 5, y: 3), control: CGPoint(x: 3, y: 3))
            p.addLine(to: CGPoint(x: 8, y: 3))
            // Top-right
            p.move(to: CGPoint(x: 21, y: 8))
            p.addLine(to: CGPoint(x: 21, y: 5))
            p.addQuadCurve(to: CGPoint(x: 19, y: 3), control: CGPoint(x: 21, y: 3))
            p.addLine(to: CGPoint(x: 16, y: 3))
            // Bottom-left
            p.move(to: CGPoint(x: 3, y: 16))
            p.addLine(to: CGPoint(x: 3, y: 19))
            p.addQuadCurve(to: CGPoint(x: 5, y: 21), control: CGPoint(x: 3, y: 21))
            p.addLine(to: CGPoint(x: 8, y: 21))
            // Bottom-right
            p.move(to: CGPoint(x: 21, y: 16))
            p.addLine(to: CGPoint(x: 21, y: 19))
            p.addQuadCurve(to: CGPoint(x: 19, y: 21), control: CGPoint(x: 21, y: 21))
            p.addLine(to: CGPoint(x: 16, y: 21))
            // Crossbar
            p.move(to: CGPoint(x: 7, y: 12))
            p.addLine(to: CGPoint(x: 17, y: 12))
        }
    }
}

struct IconSearch: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.addEllipse(in: CGRect(x: 4, y: 4, width: 14, height: 14))
            p.move(to: CGPoint(x: 20, y: 20))
            p.addLine(to: CGPoint(x: 16.5, y: 16.5))
        }
    }
}

struct IconChevR: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 9, y: 6))
            p.addLine(to: CGPoint(x: 15, y: 12))
            p.addLine(to: CGPoint(x: 9, y: 18))
        }
    }
}

struct IconChevL: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 15, y: 6))
            p.addLine(to: CGPoint(x: 9, y: 12))
            p.addLine(to: CGPoint(x: 15, y: 18))
        }
    }
}

struct IconChevD: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 6, y: 9))
            p.addLine(to: CGPoint(x: 12, y: 15))
            p.addLine(to: CGPoint(x: 18, y: 9))
        }
    }
}

struct IconX: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 6, y: 6))
            p.addLine(to: CGPoint(x: 18, y: 18))
            p.move(to: CGPoint(x: 18, y: 6))
            p.addLine(to: CGPoint(x: 6, y: 18))
        }
    }
}

struct IconCheck: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 5, y: 12))
            p.addLine(to: CGPoint(x: 10, y: 17))
            p.addLine(to: CGPoint(x: 20, y: 7))
        }
    }
}

struct IconLeaf: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 4, y: 20))
            p.addCurve(to: CGPoint(x: 20, y: 6),
                       control1: CGPoint(x: 4, y: 12), control2: CGPoint(x: 10, y: 6))
            p.addCurve(to: CGPoint(x: 6, y: 22),
                       control1: CGPoint(x: 20, y: 16), control2: CGPoint(x: 14, y: 22))
            p.addQuadCurve(to: CGPoint(x: 4, y: 20), control: CGPoint(x: 4, y: 22))
            p.move(to: CGPoint(x: 4, y: 20))
            p.addCurve(to: CGPoint(x: 18, y: 12),
                       control1: CGPoint(x: 8, y: 16), control2: CGPoint(x: 12, y: 14))
        }
    }
}

struct IconBolt: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 13, y: 2))
            p.addLine(to: CGPoint(x: 4, y: 14))
            p.addLine(to: CGPoint(x: 11, y: 14))
            p.addLine(to: CGPoint(x: 10, y: 22))
            p.addLine(to: CGPoint(x: 19, y: 10))
            p.addLine(to: CGPoint(x: 12, y: 10))
            p.addLine(to: CGPoint(x: 13, y: 2))
            p.closeSubpath()
        }
    }
}

struct IconReceipt: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 5, y: 3))
            p.addLine(to: CGPoint(x: 5, y: 21))
            p.addLine(to: CGPoint(x: 7, y: 19.5))
            p.addLine(to: CGPoint(x: 9, y: 21))
            p.addLine(to: CGPoint(x: 11, y: 19.5))
            p.addLine(to: CGPoint(x: 13, y: 21))
            p.addLine(to: CGPoint(x: 15, y: 19.5))
            p.addLine(to: CGPoint(x: 17, y: 21))
            p.addLine(to: CGPoint(x: 19, y: 19.5))
            p.addLine(to: CGPoint(x: 19, y: 3))
            p.addLine(to: CGPoint(x: 17, y: 4.5))
            p.addLine(to: CGPoint(x: 15, y: 3))
            p.addLine(to: CGPoint(x: 13, y: 4.5))
            p.addLine(to: CGPoint(x: 11, y: 3))
            p.addLine(to: CGPoint(x: 9, y: 4.5))
            p.addLine(to: CGPoint(x: 7, y: 3))
            p.addLine(to: CGPoint(x: 5, y: 4.5))
            p.closeSubpath()
            p.move(to: CGPoint(x: 8, y: 8))
            p.addLine(to: CGPoint(x: 16, y: 8))
            p.move(to: CGPoint(x: 8, y: 12))
            p.addLine(to: CGPoint(x: 16, y: 12))
            p.move(to: CGPoint(x: 8, y: 16))
            p.addLine(to: CGPoint(x: 13, y: 16))
        }
    }
}

struct IconWave: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 2, y: 12))
            p.addCurve(to: CGPoint(x: 7, y: 10),
                       control1: CGPoint(x: 4, y: 12), control2: CGPoint(x: 4, y: 10))
            p.addCurve(to: CGPoint(x: 12, y: 12),
                       control1: CGPoint(x: 10, y: 10), control2: CGPoint(x: 10, y: 12))
            p.addCurve(to: CGPoint(x: 17, y: 10),
                       control1: CGPoint(x: 14, y: 12), control2: CGPoint(x: 14, y: 10))
            p.addCurve(to: CGPoint(x: 22, y: 12),
                       control1: CGPoint(x: 20, y: 10), control2: CGPoint(x: 20, y: 12))
            p.move(to: CGPoint(x: 2, y: 17))
            p.addCurve(to: CGPoint(x: 7, y: 15),
                       control1: CGPoint(x: 4, y: 17), control2: CGPoint(x: 4, y: 15))
            p.addCurve(to: CGPoint(x: 12, y: 17),
                       control1: CGPoint(x: 10, y: 15), control2: CGPoint(x: 10, y: 17))
            p.addCurve(to: CGPoint(x: 17, y: 15),
                       control1: CGPoint(x: 14, y: 17), control2: CGPoint(x: 14, y: 15))
            p.addCurve(to: CGPoint(x: 22, y: 17),
                       control1: CGPoint(x: 20, y: 15), control2: CGPoint(x: 20, y: 17))
        }
    }
}

struct IconDroplet: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 12, y: 3))
            p.addCurve(to: CGPoint(x: 19, y: 16),
                       control1: CGPoint(x: 16, y: 8), control2: CGPoint(x: 19, y: 12))
            p.addArc(center: CGPoint(x: 12, y: 16), radius: 7,
                     startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            p.addCurve(to: CGPoint(x: 12, y: 3),
                       control1: CGPoint(x: 5, y: 12), control2: CGPoint(x: 8, y: 8))
            p.closeSubpath()
        }
    }
}

struct IconFactory: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 3, y: 21))
            p.addLine(to: CGPoint(x: 3, y: 10))
            p.addLine(to: CGPoint(x: 9, y: 14))
            p.addLine(to: CGPoint(x: 9, y: 10))
            p.addLine(to: CGPoint(x: 15, y: 14))
            p.addLine(to: CGPoint(x: 15, y: 7))
            p.addLine(to: CGPoint(x: 21, y: 4))
            p.addLine(to: CGPoint(x: 21, y: 21))
            p.addLine(to: CGPoint(x: 3, y: 21))
            p.closeSubpath()
            p.move(to: CGPoint(x: 8, y: 17))
            p.addLine(to: CGPoint(x: 9, y: 17))
            p.move(to: CGPoint(x: 13, y: 17))
            p.addLine(to: CGPoint(x: 14, y: 17))
            p.move(to: CGPoint(x: 18, y: 17))
            p.addLine(to: CGPoint(x: 19, y: 17))
        }
    }
}

struct IconBox: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 21, y: 8))
            p.addLine(to: CGPoint(x: 21, y: 20))
            p.addLine(to: CGPoint(x: 3, y: 20))
            p.addLine(to: CGPoint(x: 3, y: 8))
            p.move(to: CGPoint(x: 2, y: 5))
            p.addLine(to: CGPoint(x: 22, y: 5))
            p.addLine(to: CGPoint(x: 22, y: 8))
            p.addLine(to: CGPoint(x: 2, y: 8))
            p.closeSubpath()
            p.move(to: CGPoint(x: 10, y: 12))
            p.addLine(to: CGPoint(x: 14, y: 12))
        }
    }
}

struct IconFlash: View {
    var size: CGFloat = 24
    var body: some View { IconBolt(size: size).id("flash") }
}

struct IconSettings: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.addEllipse(in: CGRect(x: 9, y: 9, width: 6, height: 6))
            // Outer gear approximated as 8 spokes
            for i in 0..<8 {
                let a = Double(i) * .pi / 4
                let inner = CGPoint(x: 12 + cos(a) * 6, y: 12 + sin(a) * 6)
                let outer = CGPoint(x: 12 + cos(a) * 9, y: 12 + sin(a) * 9)
                p.move(to: inner)
                p.addLine(to: outer)
            }
        }
    }
}

struct IconShield: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 12, y: 22))
            p.addCurve(to: CGPoint(x: 20, y: 11),
                       control1: CGPoint(x: 17, y: 19), control2: CGPoint(x: 20, y: 16))
            p.addLine(to: CGPoint(x: 20, y: 5))
            p.addLine(to: CGPoint(x: 12, y: 2))
            p.addLine(to: CGPoint(x: 4, y: 5))
            p.addLine(to: CGPoint(x: 4, y: 11))
            p.addCurve(to: CGPoint(x: 12, y: 22),
                       control1: CGPoint(x: 4, y: 16), control2: CGPoint(x: 7, y: 19))
            p.closeSubpath()
        }
    }
}

struct IconSwap: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 7, y: 4))
            p.addLine(to: CGPoint(x: 3, y: 8))
            p.addLine(to: CGPoint(x: 7, y: 12))
            p.move(to: CGPoint(x: 3, y: 8))
            p.addLine(to: CGPoint(x: 17, y: 8))
            p.move(to: CGPoint(x: 17, y: 20))
            p.addLine(to: CGPoint(x: 21, y: 16))
            p.addLine(to: CGPoint(x: 17, y: 12))
            p.move(to: CGPoint(x: 21, y: 16))
            p.addLine(to: CGPoint(x: 7, y: 16))
        }
    }
}

struct IconInfo: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.addEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))
            p.move(to: CGPoint(x: 12, y: 16))
            p.addLine(to: CGPoint(x: 12, y: 12))
            p.move(to: CGPoint(x: 12, y: 8))
            p.addLine(to: CGPoint(x: 12.01, y: 8))
        }
    }
}

struct IconBell: View {
    var size: CGFloat = 24
    var body: some View {
        icon(size) { p in
            p.move(to: CGPoint(x: 6, y: 8))
            p.addArc(center: CGPoint(x: 12, y: 8), radius: 6,
                     startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            p.addCurve(to: CGPoint(x: 21, y: 16),
                       control1: CGPoint(x: 18, y: 15), control2: CGPoint(x: 21, y: 16))
            p.addLine(to: CGPoint(x: 3, y: 16))
            p.addCurve(to: CGPoint(x: 6, y: 8),
                       control1: CGPoint(x: 3, y: 16), control2: CGPoint(x: 6, y: 15))
            p.move(to: CGPoint(x: 10, y: 21))
            p.addQuadCurve(to: CGPoint(x: 14, y: 21), control: CGPoint(x: 12, y: 23))
        }
    }
}
