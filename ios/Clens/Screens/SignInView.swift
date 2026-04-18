import SwiftUI

struct SignInView: View {
    @EnvironmentObject var router: AppRouter
    @State private var email: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Clens")
                .font(.serif(56))
                .padding(.top, 70)
            Text("OCEAN SCORE · SEA BUCKS")
                .font(.system(size: 12))
                .tracking(2)
                .foregroundStyle(Color.ink3)
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text("Create an account")
                    .font(.system(size: 22, weight: .semibold))
                Text("Enter your email to sign up for this app")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.ink2)
            }
            .padding(.top, 52)

            TextField("email@domain.com", text: $email)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.top, 26)

            Button(action: continueAction) {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.ink))
            }
            .padding(.top, 10)

            HStack(spacing: 10) {
                Rectangle().fill(Color.black.opacity(0.1)).frame(height: 1)
                Text("or").font(.system(size: 12)).foregroundStyle(Color.ink3)
                Rectangle().fill(Color.black.opacity(0.1)).frame(height: 1)
            }
            .padding(.vertical, 22)

            providerButton(title: "Continue with Google") {
                GoogleGlyph().frame(width: 16, height: 16)
            }

            providerButton(title: "Continue with Apple") {
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.ink)
            }
            .padding(.top, 8)

            Spacer()

            Text(legalText)
                .font(.system(size: 11))
                .foregroundStyle(Color.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
    }

    private func continueAction() {
        withAnimation { router.authed = true }
    }

    private var legalText: AttributedString {
        var s = AttributedString("By clicking continue, you agree to our Terms of Service and Privacy Policy")
        if let r = s.range(of: "Terms of Service") {
            s[r].underlineStyle = .single
        }
        if let r = s.range(of: "Privacy Policy") {
            s[r].underlineStyle = .single
        }
        return s
    }

    @ViewBuilder
    private func providerButton<Glyph: View>(title: String, @ViewBuilder glyph: () -> Glyph) -> some View {
        Button(action: continueAction) {
            HStack(spacing: 10) {
                glyph()
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: 0xF4F3EE))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

private struct GoogleGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let scale = s / 24
            let t = CGAffineTransform(scaleX: scale, y: scale)
            // Blue
            var p1 = Path()
            p1.move(to: CGPoint(x: 22.6, y: 12.2))
            p1.addCurve(to: CGPoint(x: 22.4, y: 10.1),
                        control1: CGPoint(x: 22.6, y: 11.5), control2: CGPoint(x: 22.5, y: 10.8))
            p1.addLine(to: CGPoint(x: 12, y: 10.1))
            p1.addLine(to: CGPoint(x: 12, y: 14.1))
            p1.addLine(to: CGPoint(x: 18, y: 14.1))
            p1.addCurve(to: CGPoint(x: 15.8, y: 17.5),
                        control1: CGPoint(x: 17.7, y: 15.6), control2: CGPoint(x: 16.9, y: 16.7))
            p1.addLine(to: CGPoint(x: 19.4, y: 20.3))
            p1.addCurve(to: CGPoint(x: 22.6, y: 12.2),
                        control1: CGPoint(x: 21.4, y: 18.4), control2: CGPoint(x: 22.6, y: 15.6))
            p1.closeSubpath()
            ctx.fill(p1.applying(t), with: .color(Color(hex: 0x4285F4)))

            // Green
            var p2 = Path()
            p2.move(to: CGPoint(x: 12, y: 23))
            p2.addCurve(to: CGPoint(x: 19.2, y: 20.4),
                        control1: CGPoint(x: 14.9, y: 23), control2: CGPoint(x: 17.4, y: 22))
            p2.addLine(to: CGPoint(x: 15.6, y: 17.6))
            p2.addCurve(to: CGPoint(x: 12, y: 18.6),
                        control1: CGPoint(x: 14.6, y: 18.3), control2: CGPoint(x: 13.4, y: 18.6))
            p2.addCurve(to: CGPoint(x: 6, y: 14.2),
                        control1: CGPoint(x: 9.2, y: 18.6), control2: CGPoint(x: 6.8, y: 16.7))
            p2.addLine(to: CGPoint(x: 2.3, y: 17))
            p2.addCurve(to: CGPoint(x: 12, y: 23),
                        control1: CGPoint(x: 4, y: 20.6), control2: CGPoint(x: 7.7, y: 23))
            p2.closeSubpath()
            ctx.fill(p2.applying(t), with: .color(Color(hex: 0x34A853)))

            // Yellow
            var p3 = Path()
            p3.move(to: CGPoint(x: 6, y: 14.2))
            p3.addCurve(to: CGPoint(x: 6, y: 10.8),
                        control1: CGPoint(x: 5.6, y: 13.1), control2: CGPoint(x: 5.6, y: 11.9))
            p3.addLine(to: CGPoint(x: 6, y: 8))
            p3.addLine(to: CGPoint(x: 2.3, y: 8))
            p3.addCurve(to: CGPoint(x: 2.3, y: 18),
                        control1: CGPoint(x: 0.8, y: 11), control2: CGPoint(x: 0.8, y: 15))
            p3.addLine(to: CGPoint(x: 6, y: 14.2))
            p3.closeSubpath()
            ctx.fill(p3.applying(t), with: .color(Color(hex: 0xFBBC05)))

            // Red
            var p4 = Path()
            p4.move(to: CGPoint(x: 12, y: 5.6))
            p4.addCurve(to: CGPoint(x: 16.1, y: 7.2),
                        control1: CGPoint(x: 13.6, y: 5.6), control2: CGPoint(x: 15, y: 6.1))
            p4.addLine(to: CGPoint(x: 19.2, y: 4.2))
            p4.addCurve(to: CGPoint(x: 2.3, y: 8),
                        control1: CGPoint(x: 17, y: 1.7), control2: CGPoint(x: 7.5, y: 1.7))
            p4.addLine(to: CGPoint(x: 6, y: 10.8))
            p4.addCurve(to: CGPoint(x: 12, y: 5.6),
                        control1: CGPoint(x: 6.8, y: 8.3), control2: CGPoint(x: 9.2, y: 6.4))
            p4.closeSubpath()
            ctx.fill(p4.applying(t), with: .color(Color(hex: 0xEA4335)))
        }
    }
}
