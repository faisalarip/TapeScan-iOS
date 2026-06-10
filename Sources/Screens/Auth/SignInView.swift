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

    @State private var email = "alex@studio.co"
    @State private var password = ""
    @State private var showPassword = false
    @State private var showForgotPassword = false

    /// Cross-link to the create-account screen. The `.auth` phase only knows the
    /// user is unauthenticated, so the SignIn ⇄ CreateAccount toggle is owned by
    /// the parent ``AuthFlowView`` and threaded in here. Default no-op keeps the
    /// screen renderable standalone (#Preview / isolated use).
    private let onCreateAccount: () -> Void

    /// - Parameter onCreateAccount: invoked when the "Create account" link is tapped.
    public init(onCreateAccount: @escaping () -> Void = {}) {
        self.onCreateAccount = onCreateAccount
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
        // Password reset is an `auth` backend seam (see GO-LIVE.md). The stub
        // surfaces an honest confirmation alert rather than silently no-op'ing.
        .alert("Reset password", isPresented: $showForgotPassword) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We'll email a reset link to \(email.isEmpty ? "your account" : email).")
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
                BrandLockup(sub: "Sign in to sync your measurements")
                    .padding(.bottom, 18)
            }
        }
        .frame(height: 230)
        .clipped()
    }

    // MARK: - Form

    private var form: some View {
        VStack(spacing: 12) {
            SocialButton(kind: .apple) { appState.completeAuth() }
            SocialButton(kind: .google) { appState.completeAuth() }

            OrDivider().padding(.vertical, 4)

            AuthField(label: "Email", text: $email, placeholder: "you@studio.co")
            AuthField(label: "Password",
                      text: $password,
                      placeholder: "••••••••••",
                      isSecure: !showPassword,
                      trailing: {
                          Button(showPassword ? "Hide" : "Show") {
                              showPassword.toggle()
                          }
                          .font(Theme.sans(12.5, weight: .semibold))
                          .foregroundStyle(theme.accent)
                          .buttonStyle(.plain)
                      })

            HStack {
                Spacer()
                // Tappable per the spec; keeps the source's resting look
                // (right-aligned, ink2, 13pt) while meeting the 44pt target.
                Button { showForgotPassword = true } label: {
                    Text("Forgot password?")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.ink2)
                        .frame(minHeight: 44, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Forgot password")
            }
            .padding(.top, -2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
    }

    // MARK: - Footer (CTA + create-account link)

    private var footer: some View {
        VStack(spacing: 16) {
            PrimaryButton(title: "Sign In") { appState.completeAuth() }
                .accessibilityLabel("Sign in")

            Button(action: onCreateAccount) {
                HStack(spacing: 4) {
                    Text("New here?")
                        .foregroundStyle(Theme.ink3)
                    Text("Create account")
                        .foregroundStyle(theme.accent)
                        .fontWeight(.semibold)
                }
                .font(Theme.sans(14))
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create account")
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
