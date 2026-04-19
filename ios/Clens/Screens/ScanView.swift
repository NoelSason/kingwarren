import SwiftUI
import AVFoundation

struct ScanView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var coordinator: ScanCoordinator
    @StateObject private var camera = CameraService()
    @State private var processing: Bool = false
    @State private var lastHandledBarcode: String? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Live camera preview, or a denied-permission fallback.
            switch camera.permission {
            case .authorized:
                if camera.unavailable {
                    unavailableOverlay
                } else {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()
                }
            case .denied:
                deniedOverlay
            case .notDetermined:
                Color(hex: 0x0A0A09).ignoresSafeArea()
            }

            // Dim vignette so the reticle reads well over the live feed.
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.2), Color.black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                topChrome
                    .padding(.top, 50)
                Spacer()
            }

            reticle

            // Status / hint + bottom controls.
            VStack {
                Spacer()
                statusOrHint
                    .padding(.bottom, 220)
                bottomControls
                    .padding(.bottom, 54)
            }
        }
        .ignoresSafeArea()
        .task {
            coordinator.reset()
            await camera.start(mode: sessionMode(for: router.scanMode))
        }
        .onDisappear {
            // Fully tear down before returning so the next view doesn't
            // receive a half-alive capture session (the FigXPC asserts).
            camera.stop()
        }
        .onChange(of: router.scanMode) { _, newMode in
            let desired = sessionMode(for: newMode)
            camera.switchMode(to: desired)
            lastHandledBarcode = nil
        }
        .onChange(of: camera.lastDetectedBarcode) { _, barcode in
            guard let barcode, barcode != lastHandledBarcode, !processing else { return }
            guard router.scanMode == .product else { return }
            lastHandledBarcode = barcode
            Task { await handleBarcode(barcode) }
        }
        .onChange(of: coordinator.liveProduct) { _, new in
            guard let new else { return }
            if !router.stack.contains(where: { if case .scanResult = $0 { return true } else { return false } }) {
                camera.stop()
                DispatchQueue.main.async {
                    router.pop()
                    router.push(.scanResult(pid: new.id))
                }
            }
        }
        .onChange(of: coordinator.liveReceipt) { _, new in
            guard new != nil else { return }
            if !router.stack.contains(where: { if case .receipt = $0 { return true } else { return false } }) {
                camera.stop()
                DispatchQueue.main.async {
                    router.pop()
                    router.push(.receipt)
                }
            }
        }
    }

    private func sessionMode(for scanMode: ScanMode) -> CameraService.Mode {
        scanMode == .product ? .barcode : .photo
    }

    // MARK: - Subviews

    private var topChrome: some View {
        HStack {
            chromeButton { router.pop() } content: {
                IconX(size: 18).foregroundStyle(.white)
            }
            Spacer()
            Text(titleForMode(router.scanMode))
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.55)))
            Spacer()
            chromeButton {
                camera.toggleTorch()
            } content: {
                IconBolt(size: 16)
                    .foregroundStyle(camera.torchOn ? Color.yellow : .white)
            }
            .opacity(camera.torchSupported ? 1 : 0.35)
            .disabled(!camera.torchSupported)
        }
        .padding(.horizontal, 16)
    }

    private func titleForMode(_ mode: ScanMode) -> String {
        switch mode {
        case .product: return "SCAN ITEM"
        case .receipt: return "SCAN RECEIPT"
        case .recycle: return "SCAN RECYCLING"
        }
    }

    private func chromeButton<C: View>(action: @escaping () -> Void, @ViewBuilder content: () -> C) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.black.opacity(0.65))
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
                content()
            }
            .frame(width: 40, height: 40)
        }
    }

    private var reticle: some View {
        let size: CGFloat = router.scanMode == .product ? 240 : 300
        return ZStack {
            reticleCorners
            if processing {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: 0x6FCBE4), lineWidth: 2)
                    .shadow(color: Color(hex: 0x6FCBE4).opacity(0.6), radius: 18)
            }
        }
        .frame(width: 240, height: size)
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

    @ViewBuilder
    private var statusOrHint: some View {
        switch coordinator.status {
        case .busy(let msg):
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text(msg).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.45)))
        case .error(let msg):
            Text(msg)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color.red.opacity(0.7)))
                .padding(.horizontal, 32)
        case .idle:
            Text(hintForMode(router.scanMode))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func hintForMode(_ mode: ScanMode) -> String {
        switch mode {
        case .product: return "Center the barcode in frame"
        case .receipt: return "Hold the receipt flat and tap the shutter"
        case .recycle: return "Frame the recycling and tap the shutter"
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 24) {
                modeTab(title: "Item",    mode: .product)
                modeTab(title: "Receipt", mode: .receipt)
                modeTab(title: "Recycle", mode: .recycle)
            }
            Button {
                handleShutter()
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
                .opacity(processing ? 0.5 : 1.0)
            }
            .disabled(processing)
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

    private var unavailableOverlay: some View {
        ZStack {
            Color(hex: 0x0A0A09).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Camera unavailable")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text("This device has no camera, or the camera failed to start. Try again on a physical iPhone.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }

    private var deniedOverlay: some View {
        VStack(spacing: 14) {
            Text("Camera access needed")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("Enable the camera in Settings → Clens to scan barcodes and receipts.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Capsule().fill(Color.white))
            .foregroundStyle(Color.ink)
        }
    }

    // MARK: - Actions

    private func handleShutter() {
        switch router.scanMode {
        case .product:
            // In product mode the barcode stream drives navigation; the
            // shutter captures the label as a fallback for non-barcoded items.
            Task { await captureLabel() }
        case .receipt:
            Task { await captureReceipt() }
        case .recycle:
            // Not part of the MVP — just bounce back.
            router.pop()
        }
    }

    private func handleBarcode(_ barcode: String) async {
        processing = true
        defer { processing = false }
        await coordinator.handleBarcode(barcode)
    }

    private func captureLabel() async {
        guard !processing else { return }
        processing = true
        defer { processing = false }
        do {
            let data = try await camera.capturePhoto()
            await coordinator.handleLabelImage(data)
        } catch {
            coordinator.status = .error("Couldn't capture photo.")
        }
    }

    private func captureReceipt() async {
        guard !processing else { return }
        processing = true
        defer { processing = false }
        do {
            let data = try await camera.capturePhoto()
            await coordinator.handleReceiptImage(data)
        } catch {
            coordinator.status = .error("Couldn't capture photo.")
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
