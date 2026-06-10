// RootView.swift — gates Auth → Onboarding → Main on AppState.phase.

import SwiftUI

/// The application root. Switches between the auth flow, onboarding flow and
/// the main tabbed experience based on ``AppState/phase``:
///
///   .auth       → ``AuthFlowView``       (SignIn ⇄ CreateAccount → Verify)
///   .onboarding → ``OnboardingFlowView`` (Welcome → Permission → Calibrate)
///   .main       → ``MainTabView``        (Measure / Rooms / History / Settings)
public struct RootView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            switch appState.phase {
            case .auth:
                AuthFlowView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingFlowView()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.phase)
        // Derive + install the live theme; re-runs whenever any tweak changes.
        .installTheme(Theme(appState))
        .modifier(DebugPaywallPresenter())
    }
}

/// DEBUG-only modifier that auto-presents the paywall when launched with
/// `-uiPaywall`. A no-op in release builds.
private struct DebugPaywallPresenter: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        #if DEBUG
        content.fullScreenCover(
            isPresented: .init(
                get: { appState.debugPaywallContext != nil },
                set: { if !$0 { appState.debugPaywallContext = nil } })
        ) {
            PaywallView(context: appState.debugPaywallContext ?? .quotaExhausted) {
                appState.debugPaywallContext = nil
            }
            .environment(appState)
            .installTheme(Theme(appState))
        }
        #else
        content
        #endif
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
