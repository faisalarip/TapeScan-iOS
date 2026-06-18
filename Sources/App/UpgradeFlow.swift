// UpgradeFlow.swift — gates the paywall behind sign-in.
//
// Tapping "Upgrade" must show the login page FIRST, then the paywall: Pro is
// account-tied (cloud sync of unlimited rooms & history), so a subscription
// always belongs to an account. If the user is already signed in, the paywall
// is presented directly. Skipping or cancelling sign-in cancels the upgrade —
// no paywall is shown. The paywall is presented from the auth sheet's
// `onDismiss` so the two modals never overlap (SwiftUI presents the cover only
// after the sheet has fully dismissed).

import SwiftUI

extension View {
    /// Drives the sign-in-then-paywall upgrade flow. Bind `isPresented` to the
    /// upgrade trigger (set it `true` from the "Upgrade" control); `context` is
    /// read at trigger time so quota-dependent copy stays truthful.
    func upgradeFlow(isPresented: Binding<Bool>,
                     appState: AppState,
                     context: @escaping () -> PaywallContext) -> some View {
        modifier(UpgradeFlowModifier(trigger: isPresented,
                                     appState: appState,
                                     context: context))
    }
}

private struct UpgradeFlowModifier: ViewModifier {
    @Binding var trigger: Bool
    let appState: AppState
    let context: () -> PaywallContext

    @State private var presentAuth = false
    @State private var presentPaywall = false
    /// Context captured when the flow starts, replayed when the paywall opens.
    @State private var pending: PaywallContext?

    func body(content: Content) -> some View {
        content
            // Edge-trigger: the control sets `trigger = true`; consume it and
            // branch on auth. Already signed in → paywall; otherwise → login.
            .onChange(of: trigger) { _, started in
                guard started else { return }
                trigger = false
                pending = context()
                if appState.isAuthenticated {
                    presentPaywall = true
                } else {
                    presentAuth = true
                }
            }
            // Present the paywall only AFTER the login sheet is fully dismissed,
            // and only if the user actually signed in (skip/cancel → no paywall).
            .sheet(isPresented: $presentAuth, onDismiss: {
                if appState.isAuthenticated, pending != nil {
                    presentPaywall = true
                } else {
                    pending = nil
                }
            }) {
                AuthFlowView { presentAuth = false }
                    .environment(appState)
                    .installTheme(Theme(appState))
            }
            .fullScreenCover(isPresented: $presentPaywall, onDismiss: { pending = nil }) {
                PaywallView(context: pending ?? .quotaExhausted) {
                    presentPaywall = false
                }
                .environment(appState)
                .installTheme(Theme(appState))
            }
    }
}
