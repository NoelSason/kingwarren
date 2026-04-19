import SwiftUI

struct SignInView: View {
    @EnvironmentObject var router: AppRouter

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode { case signIn, signUp }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Clens")
                    .font(.serif(56))
                    .foregroundStyle(Color.ink)
                    .padding(.top, 70)
                Text("OCEAN SCORE · SEA BUCKS")
                    .font(.system(size: 12))
                    .tracking(2)
                    .foregroundStyle(Color.ink3)
                    .padding(.top, 4)

                // Mode toggle
                HStack(spacing: 0) {
                    modeButton("Sign In", selected: mode == .signIn) { mode = .signIn; errorMessage = nil }
                    modeButton("Sign Up", selected: mode == .signUp) { mode = .signUp; errorMessage = nil }
                }
                .background(Color.fill1, in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 40)

                // Error banner
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bad)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.bad.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 20)
                }

                VStack(spacing: 12) {
                    if mode == .signUp {
                        field("Display Name", text: $displayName, placeholder: "Your name")
                        field("Username", text: $username, placeholder: "username")
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    emailField
                    passwordField("Password", text: $password)
                    if mode == .signUp {
                        passwordField("Confirm Password", text: $confirmPassword)
                    }
                }
                .padding(.top, 24)

                Button(action: submit) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.ocean)
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(mode == .signIn ? "Sign In" : "Create Account")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .disabled(isLoading)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.8).onEnded { _ in
                        submitAdminSignIn()
                    }
                )
                .padding(.top, 16)

                Spacer(minLength: 40)

                Text(legalText)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
    }

    // MARK: - Actions

    private func submit() {
        errorMessage = nil
        if mode == .signUp {
            guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Display name is required."; return
            }
            let u = username.trimmingCharacters(in: .whitespaces).lowercased()
            guard u.count >= 3, u.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
                errorMessage = "Username must be 3+ characters, letters/numbers/underscores only."; return
            }
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match."; return
            }
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."; return
        }

        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let session: AuthSession
                if mode == .signIn {
                    session = try await AuthService.shared.signIn(email: email.lowercased(), password: password)
                } else {
                    session = try await AuthService.shared.signUp(
                        email: email.lowercased(),
                        password: password,
                        username: username.trimmingCharacters(in: .whitespaces).lowercased(),
                        displayName: displayName.trimmingCharacters(in: .whitespaces)
                    )
                }
                await MainActor.run {
                    router.session = session
                    withAnimation { router.authed = true }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // Admin long-press shortcut: fake a local session so the demo works offline.
    private func submitAdminSignIn() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        errorMessage = nil
        let session = AuthSession(
            accessToken: "local-admin-" + UUID().uuidString,
            refreshToken: "local-admin-refresh",
            userID: "admin-local",
            email: "admin@clens.local",
            username: "admin",
            displayName: "Admin"
        )
        router.session = session
        withAnimation { router.authed = true }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func modeButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Color.ink : Color.ink3)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(selected ? Color.surface : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .padding(3)
        }
    }

    private var emailField: some View {
        TextField("email@domain.com", text: $email)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .styledInput()
    }

    private func passwordField(_ label: String, text: Binding<String>) -> some View {
        SecureField(label, text: text)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textContentType(mode == .signUp ? .newPassword : .password)
            .styledInput()
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .styledInput()
    }

    private var legalText: AttributedString {
        var s = AttributedString("By continuing, you agree to our Terms of Service and Privacy Policy")
        if let r = s.range(of: "Terms of Service") { s[r].underlineStyle = .single }
        if let r = s.range(of: "Privacy Policy") { s[r].underlineStyle = .single }
        return s
    }
}

private extension View {
    func styledInput() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.surface)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.hair, lineWidth: 1))
            )
    }
}
