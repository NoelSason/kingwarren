import SwiftUI

struct ScanView: View {
    @EnvironmentObject var router: AppRouter
    @State private var scanning: Bool = false
    @State private var found: Product? = nil
    @State private var scanLineY: CGFloat = -120

    var body: some View {
        ZStack {
            background
            tableTexture
            // Faux subject in frame
            if router.scanMode == .product {
                FauxCan().offset(y: -40)
            } else {
                FauxReceipt().offset(y: -60)
            }

            // Top chrome
            VStack {
                topChrome
                Spacer()
            }
            .padding(.top, 50)

            // Reticle
            VStack {
                Spacer()
                ZStack {
                    reticleCorners
                    if scanning {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.clear, Color(hex: 0x6FCBE4), .clear],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(height: 2)
                            .shadow(color: Color(hex: 0x6FCBE4), radius: 12)
                            .offset(y: scanLineY)
                    }
                }
                .frame(width: 240, height: router.scanMode == .product ? 240 : 300)
                Spacer()
                Spacer()
            }
            .frame(maxHeight: .infinity)

            // Hint or found card + bottom controls
            VStack {
                Spacer()
                if let found {
                    foundCard(found).padding(.horizontal, 16).padding(.bottom, 140)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text(scanning ? "Reading barcode…" :
                         router.scanMode == .product ? "Center the barcode in frame" : "Hold the receipt flat")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 220)
                }

                bottomControls
                    .padding(.bottom, 54)
            }
        }
        .background(Color(hex: 0x0A0A09))
        .ignoresSafeArea()
        .onAppear { runScanCycle() }
        .onChange(of: router.scanMode) { _, _ in runScanCycle() }
    }

    private var background: some View {
        Group {
            if router.scanMode == .product {
                RadialGradient(
                    colors: [Color(hex: 0x3A2C15), Color(hex: 0x1A1308), Color(hex: 0x0A0805)],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: 0, endRadius: 460
                )
            } else {
                RadialGradient(
                    colors: [Color(hex: 0x6B5735), Color(hex: 0x2A2013), Color(hex: 0x0A0805)],
                    center: UnitPoint(x: 0.5, y: 0.45),
                    startRadius: 0, endRadius: 480
                )
            }
        }
    }

    private var tableTexture: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let stripe: CGFloat = 80
                ctx.opacity = 0.35
                ctx.rotate(by: .degrees(95))
                var x: CGFloat = -size.width
                var i = 0
                while x < size.width * 2 {
                    let c = (i % 2 == 0)
                        ? Color(hex: 0x78501E).opacity(0.4)
                        : Color(hex: 0x3C280F).opacity(0.4)
                    let rect = CGRect(x: x, y: -size.height, width: stripe / 2, height: size.height * 3)
                    ctx.fill(Path(rect), with: .color(c))
                    x += stripe / 2
                    i += 1
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }

    private var topChrome: some View {
        HStack {
            chromeButton { router.pop() } content: {
                IconX(size: 18).foregroundStyle(.white)
            }
            Spacer()
            Text(router.scanMode == .product ? "SCAN ITEM" : "SCAN RECEIPT")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.35)))
            Spacer()
            chromeButton {} content: {
                IconBolt(size: 16).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
    }

    private func chromeButton<C: View>(action: @escaping () -> Void, @ViewBuilder content: () -> C) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.black.opacity(0.35))
                content()
            }
            .frame(width: 36, height: 36)
        }
    }

    private var reticleCorners: some View {
        ZStack {
            cornerShape(corner: .tl)
            cornerShape(corner: .tr)
            cornerShape(corner: .bl)
            cornerShape(corner: .br)
        }
    }

    enum Corner { case tl, tr, bl, br }

    private func cornerShape(corner: Corner) -> some View {
        let size: CGFloat = 28
        return ZStack(alignment: alignment(corner)) {
            Color.clear
            CornerView(corner: corner)
                .frame(width: size, height: size)
        }
    }

    private func alignment(_ c: Corner) -> Alignment {
        switch c {
        case .tl: return .topLeading
        case .tr: return .topTrailing
        case .bl: return .bottomLeading
        case .br: return .bottomTrailing
        }
    }

    private func foundCard(_ p: Product) -> some View {
        Button {
            router.pop()
            router.push(.scanResult(pid: p.id))
        } label: {
            HStack(spacing: 12) {
                ProductThumb(pid: p.id, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.system(size: 15, weight: .semibold))
                    Text(p.brand).font(.system(size: 12)).foregroundStyle(Color.ink3)
                    HStack(spacing: 6) {
                        Circle().fill(Score.color(p.score)).frame(width: 8, height: 8)
                        Text("\(p.score)/100").font(.serif(14))
                        Text("Ocean Score").font(.system(size: 12)).foregroundStyle(Color.ink2)
                    }
                    .padding(.top, 4)
                }
                Spacer()
                ZStack {
                    Circle().fill(Color.ink).frame(width: 36, height: 36)
                    IconChevR(size: 18).foregroundStyle(.white)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.surface)
                    .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 16)
            )
            .foregroundStyle(Color.ink)
        }
        .buttonStyle(.plain)
    }

    private var bottomControls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 24) {
                modeTab(title: "Item",    mode: .product)
                modeTab(title: "Receipt", mode: .receipt)
                modeTab(title: "Recycle", mode: .recycle)
            }
            Button {
                if router.scanMode == .product {
                    router.pop(); router.push(.scanResult(pid: "monster"))
                } else {
                    router.pop(); router.push(.receipt)
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 4)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(.white)
                        .frame(width: 58, height: 58)
                        .overlay(Circle().stroke(Color.ink, lineWidth: 2))
                }
            }
        }
    }

    private func modeTab(title: String, mode: ScanMode) -> some View {
        let active = router.scanMode == mode
        return Button {
            router.scanMode = mode
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(active ? .white : .white.opacity(0.5))
                Rectangle()
                    .fill(active ? .white : .clear)
                    .frame(height: 2)
                    .frame(width: 30)
            }
        }
    }

    // MARK: scan cycle

    private func runScanCycle() {
        found = nil
        scanLineY = -120
        scanning = false
        guard router.scanMode == .product else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.scanning = true
            withAnimation(.linear(duration: 1.5).repeatCount(1, autoreverses: false)) {
                self.scanLineY = 120
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.scanning = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.found = Mock.products["monster"]
                }
            }
        }
    }
}

private struct CornerView: View {
    let corner: ScanView.Corner

    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            let s = size.width
            let r: CGFloat = 8
            switch corner {
            case .tl:
                p.move(to: CGPoint(x: 0, y: s))
                p.addLine(to: CGPoint(x: 0, y: r))
                p.addArc(center: CGPoint(x: r, y: r), radius: r,
                         startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
                p.addLine(to: CGPoint(x: s, y: 0))
            case .tr:
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: s - r, y: 0))
                p.addArc(center: CGPoint(x: s - r, y: r), radius: r,
                         startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
                p.addLine(to: CGPoint(x: s, y: s))
            case .bl:
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 0, y: s - r))
                p.addArc(center: CGPoint(x: r, y: s - r), radius: r,
                         startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
                p.addLine(to: CGPoint(x: s, y: s))
            case .br:
                p.move(to: CGPoint(x: s, y: 0))
                p.addLine(to: CGPoint(x: s, y: s - r))
                p.addArc(center: CGPoint(x: s - r, y: s - r), radius: r,
                         startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
                p.addLine(to: CGPoint(x: 0, y: s))
            }
            ctx.stroke(p, with: .color(.white),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Faux subjects

private struct FauxCan: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("M")
                .font(.system(size: 28, weight: .black, design: .serif))
                .italic()
                .foregroundStyle(Color(hex: 0x4FD14F))
                .shadow(color: Color(hex: 0x4FD14F), radius: 8)

            Barcode()
        }
        .frame(width: 150, height: 260)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x0A1A0A), Color(hex: 0x0E2A12), Color(hex: 0x0A1A0A)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 30, x: -20, y: 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct Barcode: View {
    let widths: [CGFloat] = [2,1,3,1,2,1,2,3,1,2,1,3,2,1,2,3,1,2,1,3,1]
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 1) {
                ForEach(widths.indices, id: \.self) { i in
                    Rectangle().fill(Color.black).frame(width: widths[i], height: 32)
                }
            }
            Text("0 70847 00003 4")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.bottom, 4)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
    }
}

private struct FauxReceipt: View {
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("WHOLE FOODS MKT")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            Text("La Jolla Village Dr")
                .font(.system(size: 8, design: .monospaced))
            Color(hex: 0x8A7640).frame(height: 1).opacity(0.7)
            Group {
                row("GRND BF 80/20", "9.99")
                row("HASS AVO x3", "4.47")
                row("MONSTER ZERO", "3.49")
                row("ORG OATS", "5.99")
                row("ORG TOFU", "4.29")
                row("LENTILS GRN", "2.18")
            }
            Color(hex: 0x8A7640).frame(height: 1).opacity(0.7)
            HStack {
                Text("TOTAL").font(.system(size: 10, weight: .bold, design: .monospaced))
                Spacer()
                Text("$68.42").font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .padding(.top, 2)
            Text("THANK YOU")
                .font(.system(size: 8, design: .monospaced))
                .opacity(0.6)
                .padding(.top, 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(width: 200)
        .background(Color(hex: 0xF4EDDC))
        .foregroundStyle(Color(hex: 0x2A2112))
        .rotationEffect(.degrees(-3))
        .shadow(color: .black.opacity(0.5), radius: 30, x: -20, y: 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func row(_ name: String, _ price: String) -> some View {
        HStack {
            Text(name).font(.system(size: 9, design: .monospaced))
            Spacer()
            Text(price).font(.system(size: 9, design: .monospaced))
        }
    }
}
