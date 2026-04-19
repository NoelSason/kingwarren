import SwiftUI
import UIKit

// Shown between receipt capture and the LLM call so the user can confirm the
// photo is clear before we spend an Anthropic request on it. The ScanView
// decides whether the captured frame looked like a receipt (from the live
// ScanClassifier verdict at capture time) and passes that in — we just
// render the badge and gate the "Use Photo" button.
struct ReceiptPreviewSheet: View {
    let imageData: Data
    let isLikelyReceipt: Bool
    let onRetake: () -> Void
    let onUse: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .accessibilityLabel("Captured receipt preview")
            }

            LinearGradient(
                colors: [Color.black.opacity(0.55), .clear, Color.black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                topBar
                    .padding(.top, 50)
                Spacer()
                badge
                    .padding(.bottom, 16)
                bottomButtons
                    .padding(.bottom, 44)
            }
            .padding(.horizontal, 20)
        }
    }

    private var topBar: some View {
        HStack {
            Text("Preview")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    @ViewBuilder
    private var badge: some View {
        if isLikelyReceipt {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Looks like a receipt")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color(hex: 0x3F7D58).opacity(0.9)))
        } else {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Doesn't look like a receipt")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color(hex: 0xC7591A).opacity(0.9)))
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button(action: onRetake) {
                Text("Retake")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                    .foregroundStyle(.white)
                    .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
            }

            Button(action: onUse) {
                Text("Use Photo")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(isLikelyReceipt ? Color.white : Color.white.opacity(0.35)))
                    .foregroundStyle(isLikelyReceipt ? Color.black : Color.white.opacity(0.6))
            }
            .disabled(!isLikelyReceipt)
        }
    }
}
