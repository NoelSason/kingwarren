import SwiftUI

struct ScanHistoryView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var history: ScanHistoryStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                header.padding(.horizontal, 16).padding(.top, 24)

                if history.records.isEmpty {
                    emptyState.padding(.top, 40)
                } else {
                    VStack(spacing: 8) {
                        ForEach(history.records) { row(for: $0) }
                    }
                    .padding(.horizontal, 16)
                }

                if let err = history.lastError {
                    Text(err).font(.system(size: 12)).foregroundStyle(Color.bad)
                        .padding(.top, 8)
                }

            }
            .padding(.bottom, 96)
        }
        .background(Color.bg.ignoresSafeArea())
        .task { await history.refresh() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { router.pop() } label: {
                ZStack {
                    Circle().fill(Color.surface)
                        .overlay(Circle().stroke(Color.hair, lineWidth: 1))
                    IconChevL(size: 16).foregroundStyle(Color.ink)
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Text("Scan history").font(.serif(26))
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            IconReceipt(size: 28).foregroundStyle(Color.ink3)
            Text("No scans yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text("Scan a product or receipt and it'll show up here.")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func row(for r: ScanRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.sand)
                Group {
                    if r.kind == .receipt { IconReceipt(size: 18) }
                    else { IconBox(size: 18) }
                }
                .foregroundStyle(Color.ink2)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(r.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ink)
                if let store = r.store {
                    Text(store).font(.system(size: 12)).foregroundStyle(Color.ink3)
                }
                Text(r.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ink3)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(r.score)")
                    .font(.serif(20))
                    .foregroundStyle(Score.color(r.score))
                Text("+\(r.points) seabucks")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.kelp)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.hair, lineWidth: 1)
                )
        )
    }
}
