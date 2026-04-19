import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var profileService: ProfileService
    @AppStorage("clens.darkMode") private var darkMode: Bool = false

    private var displayName: String {
        profileService.profile?.displayName
            ?? router.session?.displayName
            ?? Mock.warren.name
    }
    private var handle: String {
        let u = profileService.profile?.username ?? router.session?.username ?? ""
        return u.isEmpty ? Mock.warren.handle : "@\(u)"
    }
    private var seabucks: Int {
        profileService.profile?.seabucks ?? Mock.warren.points
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topBar.padding(.horizontal, 16).padding(.top, 60)

                identity.padding(.top, 12)

                SectionHeader(title: "Lifetime impact")
                lifetimeTiles.padding(.horizontal, 16)

                SectionHeader(title: "Your pattern", trailing: "Inferred from 47 scans")
                archetypeCard.padding(.horizontal, 16)

                SectionHeader(title: "Account")
                accountMenu

                Spacer().frame(height: 30)
            }
            .padding(.bottom, 110)
        }
        .background(Color.bg.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                darkMode.toggle()
            } label: {
                ZStack {
                    Circle().fill(Color.surface)
                        .overlay(Circle().stroke(Color.hair, lineWidth: 1))
                    Image(systemName: darkMode ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ink)
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
    }

    private var identity: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.coral)
                .frame(width: 84, height: 84)
                .overlay(
                    Text(initials(displayName))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                )
            Text(displayName)
                .font(.serif(28))
                .padding(.top, 14)
            Text("\(handle) · La Jolla, CA")
                .font(.system(size: 13))
                .foregroundStyle(Color.ink2)
                .padding(.top, 4)
            HStack(spacing: 6) {
                IconShield(size: 12).foregroundStyle(Color.ocean)
                Text(Mock.warren.rank)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.ink)
                Text("· \(Mock.warren.streak) day streak")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ink3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.sand))
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private var lifetimeTiles: some View {
        HStack(spacing: 8) {
            StatTile(label: "SeaBucks",
                     value: "\(seabucks)",
                     sub: "points earned")
            StatTile(label: "Plastic",
                     value: String(format: "%.1f kg", Mock.warren.lifetimePlastic),
                     sub: "avoided")
            StatTile(label: "Water",
                     value: String(format: "%.1fK L", Double(Mock.warren.lifetimeWater) / 1000.0),
                     sub: "saved")
        }
    }

    private var archetypeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SHOPPER ARCHETYPE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.ink3)
            Text("Meat-leaning · low-waste")
                .font(.serif(22))
                .padding(.top, 4)
            Text("Your basket averages high on fresh produce and bulk bins, but meat purchases pull your score down by ~22 points.")
                .font(.system(size: 13))
                .foregroundStyle(Color.ink2)
                .padding(.top, 6)
                .lineSpacing(2)

            HStack(spacing: 4) {
                segment(weight: 28, color: Color(hex: 0xC7441F))
                segment(weight: 12, color: Color(hex: 0xC7591A))
                segment(weight: 24, color: Color(hex: 0xB58A20))
                segment(weight: 36, color: Color.kelp)
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .padding(.top, 12)

            HStack {
                Text("Meat 28%")
                Spacer()
                Text("Dairy 12%")
                Spacer()
                Text("Packaged 24%")
                Spacer()
                Text("Plant 36%")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Color.ink3)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.hair, lineWidth: 1)
                )
        )
    }

    private func segment(weight: CGFloat, color: Color) -> some View {
        GeometryReader { _ in
            Rectangle().fill(color)
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(weight)
    }

    private var accountMenu: some View {
        VStack(spacing: 0) {
            MenuRow(icon: AnyView(IconReceipt(size: 18)), title: "Scan history") {
                router.push(.scanHistory)
            }
            Color.hair.frame(height: 1)
            MenuRow(icon: AnyView(IconLeaf(size: 18)), title: "Preferences (diet, budget)")
            Color.hair.frame(height: 1)
            MenuRow(icon: AnyView(IconBell(size: 18)), title: "Notifications")
            Color.hair.frame(height: 1)
            MenuRow(icon: AnyView(IconShield(size: 18)), title: "Privacy & data")
            Color.hair.frame(height: 1)
            MenuRow(icon: AnyView(Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 16))), title: "Sign out") {
                router.session = nil
                withAnimation { router.authed = false }
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

    private func initials(_ name: String) -> String {
        String(name.split(separator: " ").compactMap { $0.first }.prefix(2)).uppercased()
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Color.ink3)
            Text(value)
                .font(.serif(20))
                .padding(.top, 4)
            Text(sub)
                .font(.system(size: 10.5))
                .foregroundStyle(Color.ink3)
                .padding(.top, 6)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
}

private struct MenuRow: View {
    let icon: AnyView
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: 0xF0EFE9))
                    icon.foregroundStyle(Color.ink2)
                }
                .frame(width: 32, height: 32)
                Text(title).font(.system(size: 14)).foregroundStyle(Color.ink)
                Spacer()
                IconChevR(size: 14).foregroundStyle(Color.ink3)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
