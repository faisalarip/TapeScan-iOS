// SignInView.swift — reference screen. Ported 1:1 from auth.jsx `SignIn`.
//
// This is the canonical pattern downstream screen agents should follow:
//   • Read live tokens via `@Environment(\.theme)` and app flags via
//     `@Environment(AppState.self)`.
//   • Full-bleed `ZStack` rooted on `Theme.screenBG`, ignoring safe area where
//     the design bleeds to the edges (the AR hero band here).
//   • Compose atoms from `Sources/Components` (CameraBackdrop, FeaturePoints,
//     PrimaryButton, Icon, …) instead of re-deriving styling.
//   • Density-scale radii/padding with `theme.r(_:)` / `theme.p(_:)`.
//   • Provide accessibility labels + 44pt tap targets on interactive controls.

import SwiftUI

public struct SignInView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    @State private var email = ""
    @State private var isWorking = false
    @State private var appleCoordinator = AppleSignInCoordinator()

    /// Real auth backend (Apple / Google / email OTP via Supabase).
    private let auth: any AuthService
    /// A code was sent — the parent pushes VerifyCodeView for this address.
    private let onCodeSent: (String) -> Void
    /// Signed in (Apple/Google) — the parent dismisses.
    private let onSignedIn: () -> Void
    /// "Continue without account" — accounts never gate the app.
    private let onSkip: () -> Void

    public init(auth: any AuthService,
                onCodeSent: @escaping (String) -> Void = { _ in },
                onSignedIn: @escaping () -> Void = {},
                onSkip: @escaping () -> Void = {}) {
        self.auth = auth
        self.onCodeSent = onCodeSent
        self.onSignedIn = onSignedIn
        self.onSkip = onSkip
    }

    @MainActor
    public init(onCodeSent: @escaping (String) -> Void = { _ in },
                onSignedIn: @escaping () -> Void = {},
                onSkip: @escaping () -> Void = {}) {
        self.init(auth: SupabaseAuthService.shared,
                  onCodeSent: onCodeSent, onSignedIn: onSignedIn, onSkip: onSkip)
    }

    public var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                hero
                form
                Spacer(minLength: 0)
                footer
            }
        }
    }

    // MARK: - Auth actions

    private var emailIsValid: Bool {
        email.contains("@") && email.contains(".") && email.count >= 5
    }

    private func appleTapped() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let (token, nonce) = try await appleCoordinator.signIn()
                try await auth.signInWithApple(idToken: token, nonce: nonce)
                appState.completeAuth()
                onSignedIn()
            } catch is CancellationError {
                // user dismissed the Apple sheet — silent
            } catch {
                appState.presentAlert(title: "Sign in didn't complete",
                                      message: error.localizedDescription)
            }
        }
    }

    private func googleTapped() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await auth.signInWithGoogle()
                appState.completeAuth()
                onSignedIn()
            } catch {
                appState.presentAlert(title: "Sign in didn't complete",
                                      message: error.localizedDescription)
            }
        }
    }

    private func sendCodeTapped() {
        guard !isWorking, emailIsValid else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await auth.sendEmailOTP(to: email)
                onCodeSent(email)
            } catch {
                appState.presentAlert(title: "Couldn't send the code",
                                      message: error.localizedDescription)
            }
        }
    }

    // MARK: - Hero (AR backdrop + brand lockup)

    private var hero: some View {
        ZStack {
            CameraBackdrop(accent: theme.accent, plane: true)
            FeaturePoints(accent: theme.accent)
            // fade into the screen background
            LinearGradient(
                colors: [Theme.screenBG.opacity(0.3), Theme.screenBG],
                startPoint: .top, endPoint: .bottom)

            VStack {
                Spacer()
                BrandLockup(sub: "Back up & sync your measurements")
                    .padding(.bottom, 18)
            }
        }
        .frame(height: 230)
        .clipped()
    }

    // MARK: - Form (passwordless: Apple / Google / email one-time code)

    private var form: some View {
        VStack(spacing: 12) {
            SocialButton(kind: .apple, action: appleTapped)
            SocialButton(kind: .google, action: googleTapped)

            OrDivider().padding(.vertical, 4)

            AuthField(label: "Email", text: $email, placeholder: "you@studio.co")

            Text("We'll email you a one-time code — no password needed.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .disabled(isWorking)
        .opacity(isWorking ? 0.7 : 1)
    }

    // MARK: - Footer (send code + skip)

    private var footer: some View {
        VStack(spacing: 16) {
            PrimaryButton(title: isWorking ? "Working…" : "Email me a code") {
                sendCodeTapped()
            }
            .accessibilityLabel("Email me a sign-in code")
            .disabled(isWorking || !emailIsValid)
            .opacity(emailIsValid ? 1 : 0.5)

            // Accounts are optional — the app never gates on sign-in.
            Button(action: onSkip) {
                Text("Continue without account")
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Continue without account")
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 36)
    }
}

// MARK: - Auth atoms (shared pattern for the other auth screens)

/// Brand lockup: gradient app icon + wordmark + optional subtitle.
struct BrandLockup: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    var sub: String?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                    .fill(LinearGradient(
                        colors: [theme.accent.withA(0.95), theme.accent.withA(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 66, height: 66)
                    .shadow(color: theme.accent.withA(0.4), radius: 15, y: 10)
                Icon("ruler2", size: 34, weight: 1.9, color: .white)
            }
            VStack(spacing: 3) {
                Text(appState.brand)
                    .font(Theme.sans(22, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(Theme.ink)
                if let sub {
                    Text(sub)
                        .font(Theme.sans(13.5))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
    }
}

/// Labeled text field in the auth style (dark fill, accent focus border).
struct AuthField<Trailing: View>: View {
    @Environment(\.theme) private var theme
    let label: String
    @Binding var text: String
    var placeholder: String
    var isSecure: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    @FocusState private var focused: Bool

    init(label: String,
         text: Binding<String>,
         placeholder: String,
         isSecure: Bool = false,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.isSecure = isSecure
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(Theme.sans(12))
                .tracking(0.2)
                .foregroundStyle(Theme.ink3)
            HStack(spacing: 10) {
                Group {
                    if isSecure {
                        SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.ink3))
                    } else {
                        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.ink3))
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                    }
                }
                .font(Theme.sans(15.5))
                .foregroundStyle(Theme.ink)
                .focused($focused)
                trailing()
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: theme.r(13), style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(13), style: .continuous)
                    .strokeBorder(focused ? theme.accent : Color.white.opacity(0.12),
                                  lineWidth: focused ? 1.5 : 1)
            )
        }
    }
}

/// Apple / Google social sign-in button.
struct SocialButton: View {
    @Environment(\.theme) private var theme

    enum Kind { case apple, google
        var label: String { self == .apple ? "Apple" : "Google" }
    }
    let kind: Kind
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                logo
                Text("Continue with \(kind.label)")
                    .font(Theme.sans(15.5, weight: .semibold))
            }
            .foregroundStyle(kind == .apple ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: theme.r(14), style: .continuous)
                    .fill(kind == .apple ? Color.white : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(14), style: .continuous)
                    .strokeBorder(kind == .apple ? .clear : Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue with \(kind.label)")
    }

    @ViewBuilder private var logo: some View {
        switch kind {
        case .apple:
            Image(systemName: "applelogo")
                .font(.system(size: 17))
                .foregroundStyle(.black)
        case .google:
            // Multi-color "G" approximated with SF Symbol tint.
            Image(systemName: "g.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#4285F4"))
        }
    }
}

/// "or" divider with hairlines.
struct OrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            Text("or")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.ink3)
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
        }
    }
}

#Preview {
    SignInView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
