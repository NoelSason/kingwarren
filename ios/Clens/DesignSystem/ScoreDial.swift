import SwiftUI

struct ScoreDial: View {
    let score: Int
    var size: CGFloat = 120
    var stroke: CGFloat = 10
    var showLabel: Bool = true

    @State private var animatedPct: CGFloat = 0

    private var pct: CGFloat { CGFloat(max(0, min(100, score))) / 100 }
    private var color: Color { Score.color(score) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.ink.opacity(0.07), lineWidth: stroke)

            Circle()
                .trim(from: 0, to: animatedPct)
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.serif(size * 0.38))
                    .foregroundStyle(color)
                if showLabel {
                    Text("/ 100")
                        .font(.system(size: 10, weight: .regular))
                        .tracking(0.8)
                        .foregroundStyle(Color.ink3)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedPct = pct
            }
        }
    }
}
