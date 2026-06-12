// AuthFlowView.swift — the optional sign-in flow (M7).
//
// Presented as a sheet (never a gate): post-onboarding once, and from
// Settings' "Back up & sync" entry. Passwordless: SignIn (Apple / Google /
// email) → VerifyCode for the emailed one-time code. Every path out —
// signed in, verified, or "continue without account" — just dismisses.

import SwiftUI

/// Hosts the optional SignIn → VerifyCode flow.
public struct AuthFlowView: View {
    @Environment(AppState.self) private var appState

    /// Dismiss handler (sign-in success, verification success, or skip).
    private let onDone: () -> Void

    /// Email awaiting one-time-code verification; nil shows the sign-in screen.
    @State private var pendingEmail: String?

    public init(onDone: @escaping () -> Void = {}) {
        self.onDone = onDone
    }

    public var body: some View {
        ZStack {
            if let email = pendingEmail {
                VerifyCodeView(email: email, onVerified: onDone)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                SignInView(onCodeSent: { email in pendingEmail = email },
                           onSignedIn: onDone,
                           onSkip: onDone)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: pendingEmail != nil)
    }
}

#Preview {
    AuthFlowView()
        .environment(AppState())
        .installTheme(Theme(accent: AccentOption.blue.color))
}
