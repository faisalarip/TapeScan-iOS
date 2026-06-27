// UpgradeFlow.swift — opens the paywall from any "Upgrade" trigger.
//
// Tapping "Upgrade" shows the paywall directly so the In-App Purchases are
// always viewable — App Review must be able to locate the IAPs without first
// clearing a sign-in wall (Guideline 2.1(b)). Sign-in is NOT required to see
// the plans; PaywallView still asks the user to sign in at the moment of
// purchase, because Pro is account-tied (cloud sync of unlimited rooms &
// history). `context` is captured at trigger time so quota-dependent copy stays
// truthful when the cover appears.

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

    @State private var presentPaywall = false
    /// Context captured when the flow starts, replayed when the paywall opens.
    @State private var pending: PaywallContext?

    func body(content: Content) -> some View {
        content
            // Edge-trigger: the control sets `trigger = true`; consume it and
            // open the paywall directly. The plans must be viewable without an
            // account so App Review can locate the IAPs (Guideline 2.1(b));
            // PaywallView still gates the actual purchase behind sign-in.
            .onChange(of: trigger) { _, started in
                guard started else { return }
                trigger = false
                pending = context()
                presentPaywall = true
            }
            // On dismiss, clear the captured context AND reset the live paywall
            // source (pendingSource) so a later, source-less event can't be
            // mis-attributed to this entry point. We deliberately leave
            // attribution.lastSource intact so the source-less StoreKit listener
            // can still attribute a later Ask-to-Buy approval or renewal.
            .fullScreenCover(isPresented: $presentPaywall, onDismiss: {
                pending = nil
                appState.endPaywall()
            }) {
                PaywallView(context: pending ?? .quotaExhausted) {
                    presentPaywall = false
                }
                .environment(appState)
                .installTheme(Theme(appState))
            }
    }
}
