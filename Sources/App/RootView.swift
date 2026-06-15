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
    @Environment(\.scenePhase) private var scenePhase

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
        // Capture the device's REAL safe-area insets here in the normal hierarchy
        // (where the key window reliably reports them) and stash them on AppState
        // for modal covers to read — iOS 26 `.fullScreenCover` doesn't hand its
        // content the device insets, and reading them at the cover's own body time
        // is unreliable. Re-read on each activation so rotation / dynamic changes
        // stay correct.
        .onAppear {
            print("🔵SA ▶︎ BUILD trace-v2 · RootView.onAppear — capturing window insets")
            appState.safeAreaInsets = WindowSafeArea.insets
        }
        .onChange(of: scenePhase) { _, phase in
            print("🔵SA RootView scenePhase → \(phase)")
            if phase == .active { appState.safeAreaInsets = WindowSafeArea.insets }
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
        // The single global error surface. `appAlert` is ALSO applied to each
        // modal root (Export/Paywall/Scan/Editor) so failures raised inside a
        // fullScreenCover/sheet aren't swallowed — SwiftUI presents an alert only
        // on the topmost context, never on a view that a cover is covering.
        .appAlert(appState)
        .overlay(alignment: .top) { noticeToast }
        .animation(.spring(duration: 0.35), value: appState.notice)
        .onChange(of: appState.notice) { _, notice in
            // Auto-dismiss after a beat; only clear if a newer notice hasn't replaced it.
            guard let notice else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                if appState.notice == notice { appState.notice = nil }
            }
        }
        .modifier(DebugPaywallPresenter())
    }

    /// Transient confirmation toast (top), auto-dismissed by the onChange above.
    @ViewBuilder
    private var noticeToast: some View {
        if let notice = appState.notice {
            Text(notice)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.deck))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
        }
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

// MARK: - Global alert

extension View {
    /// Surfaces the single global ``AppState/alert``. Applied to RootView AND to
    /// every modal root (fullScreenCover/sheet): SwiftUI presents an alert only on
    /// the topmost context, so an alert bound only on RootView never appears over a
    /// presented cover — silently swallowing in-modal failures (export, purchase,
    /// scan, editor). Binding the same source on each modal fixes that.
    func appAlert(_ appState: AppState) -> some View {
        alert(item: Binding(get: { appState.alert },
                            set: { appState.alert = $0 })) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message))
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
