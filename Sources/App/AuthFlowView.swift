// AuthFlowView.swift — the Auth phase coordinator.
//
// Owns the SignIn ⇄ CreateAccount cross-link that neither screen can own alone
// (the `.auth` phase only knows the user is unauthenticated). It presents:
//
//   SignIn ──"Create account"──▶ CreateAccount ──"Verify & Continue"──▶ Verify
//      ▲                              │                                    │
//      └──────── back chevron ────────┘                  completeAuth() ───┘
//
// `CreateAccountView` presents `VerifyCodeView` itself (via a fullScreenCover),
// and both `VerifyCodeView` and `SignInView`'s social buttons call
// `appState.completeAuth()`, which advances the RootView out of `.auth`.

import SwiftUI

/// Coordinates the two-screen auth surface (Sign In / Create Account) and the
/// cross-link between them. Presented by ``RootView`` for ``AppPhase/auth``.
public struct AuthFlowView: View {

    /// Whether the create-account screen is on top of sign-in.
    @State private var showCreateAccount = false

    public init() {}

    public var body: some View {
        ZStack {
            if showCreateAccount {
                CreateAccountView(
                    showSignIn: Binding(
                        get: { !showCreateAccount },
                        set: { backToSignIn in
                            // CreateAccount's back chevron sets `showSignIn = true`.
                            if backToSignIn { showCreateAccount = false }
                        }
                    )
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                SignInView {
                    showCreateAccount = true
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showCreateAccount)
    }
}

#Preview {
    AuthFlowView()
        .environment(AppState())
        .installTheme(Theme(accent: AccentOption.blue.color))
}
