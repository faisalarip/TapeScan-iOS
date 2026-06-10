// CreateAccountView.swift — registration screen. Ported 1:1 from auth.jsx
// `CreateAccount` (and the verified HTML build).
//
// Layout (top → bottom):
//   • Back chevron (→ SignIn) + "Create account" title + free-plan subtitle.
//   • Full name / Email / Password fields (Password has a "Show" toggle).
//   • Live password-requirement checks (8+ chars, one number, one symbol),
//     each flipping green (#34d399) as the rule is satisfied.
//   • Terms-agreement row (tappable checkbox) + "Create Account" CTA → Verify.
//
// Reuses the shared auth atoms (`AuthField`, `BrandLockup`, …) declared in
// SignInView.swift — those are the canonical definitions and are not redeclared.

import SwiftUI

/// Account-creation screen. Drives the sign-in ⇄ create-account cross-link and,
/// on submit, transitions to ``VerifyCodeView`` via a local navigation flag.
public struct CreateAccountView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    /// When the user submits, we present the verify-code step. Auth completion
    /// happens there ("Verify & Continue"), matching the source flow
    /// signup → verify → welcome.
    @State private var showVerify = false

    /// Cross-link back to Sign In. The auth phase only knows it is unauthenticated,
    /// so the SignIn ⇄ CreateAccount toggle is local presentation state owned here.
    @Binding var showSignIn: Bool

    @State private var fullName = "Alex Rivera"
    @State private var email = "alex@studio.co"
    @State private var password = ""
    @State private var showPassword = false
    @State private var agreedToTerms = true

    /// - Parameter showSignIn: binding the parent toggles to swap back to Sign In.
    public init(showSignIn: Binding<Bool> = .constant(false)) {
        self._showSignIn = showSignIn
    }

    public var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                form
                Spacer(minLength: 0)
                footer
            }
        }
        .fullScreenCover(isPresented: $showVerify) {
            VerifyCodeView(email: email)
                .environment(appState)
                .environment(\.theme, theme)
        }
    }

    // MARK: - Header (back button + title)

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { showSignIn = true } label: {
                // chevron mirrored to point left (source: transform scaleX(-1)).
                Icon("chevron", size: 18, weight: 2.2, color: Theme.ink2)
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to sign in")
            .padding(.bottom, 20)

            Text("Create account")
                .font(Theme.sans(28, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Theme.ink)

            Text("Free plan includes 3 exports to start.")
                .font(Theme.sans(14.5))
                .foregroundStyle(Theme.ink3)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    // MARK: - Form (fields + password requirements)

    private var form: some View {
        VStack(spacing: 14) {
            AuthField(label: "Full name", text: $fullName, placeholder: "Your name")
            AuthField(label: "Email", text: $email, placeholder: "you@studio.co")
            AuthField(label: "Password",
                      text: $password,
                      placeholder: "••••••••",
                      isSecure: !showPassword,
                      trailing: {
                          Button(showPassword ? "Hide" : "Show") {
                              showPassword.toggle()
                          }
                          .font(Theme.sans(12.5, weight: .semibold))
                          .foregroundStyle(theme.accent)
                          .buttonStyle(.plain)
                          .frame(minWidth: 44, minHeight: 44)
                          .contentShape(Rectangle())
                      })

            requirements
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    /// Live password-strength checklist. Each rule recolors as it is met.
    private var requirements: some View {
        HStack(spacing: 14) {
            RequirementCheck(label: "8+ characters", met: password.count >= 8)
            RequirementCheck(label: "One number", met: password.contains(where: \.isNumber))
            RequirementCheck(label: "One symbol", met: password.contains(where: isSymbol))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isSymbol(_ c: Character) -> Bool {
        !c.isLetter && !c.isNumber && !c.isWhitespace
    }

    // MARK: - Footer (terms + CTA)

    private var footer: some View {
        VStack(spacing: 14) {
            Button { agreedToTerms.toggle() } label: {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(agreedToTerms ? theme.accent.withA(0.95)
                                                : Color.white.opacity(0.08))
                            .frame(width: 20, height: 20)
                        if agreedToTerms {
                            Icon("check", size: 13, weight: 3, color: .white)
                        }
                    }
                    .padding(.top, 1)

                    termsText
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Agree to Terms and Privacy Policy")
            .accessibilityAddTraits(agreedToTerms ? .isSelected : [])

            PrimaryButton(title: "Create Account") {
                showVerify = true
            }
            .accessibilityLabel("Create account")
            .opacity(agreedToTerms ? 1 : 0.5)
            .disabled(!agreedToTerms)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 36)
    }

    private var termsText: Text {
        Text("I agree to the ")
            .foregroundColor(Theme.ink2)
        + Text("Terms").foregroundColor(theme.accent)
        + Text(" and ").foregroundColor(Theme.ink2)
        + Text("Privacy Policy").foregroundColor(theme.accent)
        + Text(".").foregroundColor(Theme.ink2)
    }
}

// MARK: - Password requirement chip

/// A single password-strength rule. Renders a circular check badge that turns
/// success-green when ``met`` is true, otherwise muted ink3.
private struct RequirementCheck: View {
    let label: String
    let met: Bool

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(met ? Theme.successGreen.withA(0.2)
                              : Color.white.opacity(0.08))
                    .frame(width: 16, height: 16)
                Icon("check", size: 11, weight: 3,
                     color: met ? Theme.successGreen : Theme.ink3)
            }
            Text(label)
                .font(Theme.sans(12.5))
                .foregroundStyle(met ? Theme.successGreen : Theme.ink3)
        }
        .animation(.easeInOut(duration: 0.18), value: met)
    }
}

#Preview {
    CreateAccountView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
