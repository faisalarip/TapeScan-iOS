// RootView.swift — gates Auth → Onboarding → Main on AppState.phase.

import SwiftUI

/// The application root. Switches between onboarding and the main tabbed
/// experience based on ``AppState/phase``:
///
///   .onboarding → ``OnboardingFlowView`` (Welcome → Permission → Calibrate)
///   .main       → ``MainTabView``        (Measure / Rooms / History / Settings)
///
/// Sign-in is OPTIONAL: offered once as a dismissible sheet right after
/// onboarding, and forever after from Settings ("Back up & sync").
public struct RootView: View {
    @Environment(AppState.self) private var appState

    /// One-time post-onboarding sign-in offer (never shown again after).
    @AppStorage("authOffered") private var authOffered = false
    @State private var showAuthSheet = false

    public init() {}

    public var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            switch appState.phase {
            case .auth, .onboarding:
                OnboardingFlowView()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.phase)
        .onChange(of: appState.phase) { _, phase in
            if phase == .main, !authOffered, !appState.isAuthenticated {
                authOffered = true
                showAuthSheet = true
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthFlowView { showAuthSheet = false }
                .environment(appState)
                .installTheme(Theme(appState))
        }
        // Derive + install the live theme; re-runs whenever any tweak changes.
        .installTheme(Theme(appState))
        // The single global error surface — every failure path presents here
        // via AppState.presentAlert (purchases, auth, sync, export, AR session).
        .alert(item: alertBinding) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message))
        }
        .modifier(DebugPaywallPresenter())
    }

    /// @Observable classes don't vend bindings directly; bridge manually.
    private var alertBinding: Binding<AppAlert?> {
        Binding(get: { appState.alert }, set: { appState.alert = $0 })
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
