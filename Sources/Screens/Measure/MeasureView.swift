// MeasureView.swift — the Measure tab host.
//
// The design ships THREE visual directions of the live AR Measure screen
// (Precision HUD / Minimal Focus / Pro Console). The shipped direction is
// "Precision" (MeasureAView). In DEBUG builds a small floating "HUD style"
// picker pinned to the top edge keeps all three reachable for design review;
// Release builds render Precision full-bleed with no picker.
//
// A single `SimulatedARMeasureService` is created once and injected into the
// active direction so AR intents (place/undo/finish) share one backend.

import SwiftUI

/// Which of the three Measure directions is on screen.
public enum MeasureHUDStyle: String, CaseIterable, Identifiable, Hashable {
    case precision
    case minimal
    case pro
    public var id: String { rawValue }

    /// Short label for the floating style picker.
    var label: String {
        switch self {
        case .precision: return "Precision"
        case .minimal:   return "Minimal"
        case .pro:       return "Pro"
        }
    }
}

/// Single-owner box for the AR backend, held by ``MeasureView`` via
/// `@StateObject` so `MeasureServiceFactory.make()` runs exactly once per view
/// identity (see the `serviceHost` doc comment). It publishes nothing — the
/// service itself is `@Observable` and observed directly at each use site.
@MainActor
final class MeasureServiceHost: ObservableObject {
    let service: any ARMeasureService
    init() { service = MeasureServiceFactory.make() }
}

public struct MeasureView: View {
    @Environment(\.theme) private var theme

    @State private var style: MeasureHUDStyle
    /// Owns the AR backend so it is constructed EXACTLY ONCE per MeasureView
    /// identity. `@State(initialValue: MeasureServiceFactory.make())` re-evaluates
    /// `make()` on every view re-init — e.g. a live theme/settings change while the
    /// Measure tab is on screen re-runs `MeasureView.init` — which would spin up,
    /// then immediately discard, a throwaway ARView/ARSession (on device an
    /// expensive RealityKit allocation). `@StateObject`'s autoclosure is evaluated
    /// once per identity, so the live session is never needlessly rebuilt.
    @StateObject private var serviceHost = MeasureServiceHost()
    /// Shared AR backend for whichever direction is active.
    private var service: any ARMeasureService { serviceHost.service }

    @MainActor
    public init() {
        var initial: MeasureHUDStyle = .precision
        #if DEBUG
        // DEBUG-only: `-uiMeasureDir precision|minimal|pro` sets the initial
        // direction for screenshot verification. No-op in release / without the arg.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-uiMeasureDir"), i + 1 < args.count,
           let s = MeasureHUDStyle(rawValue: args[i + 1]) {
            initial = s
        }
        #endif
        _style = State(initialValue: initial)
    }

    @Environment(\.scenePhase) private var scenePhase

    public var body: some View {
        ZStack(alignment: .top) {
            direction
            #if DEBUG
            stylePicker
            #endif
        }
        // Cold-start loading state so a launch isn't perceived as "stuck": the
        // camera feed is black until ARKit delivers its first tracked frame.
        .overlay { arLoadingOverlay }
        .animation(.easeInOut(duration: 0.3), value: isInitializing)
        .background(Theme.cameraBG.ignoresSafeArea())
        // SINGLE-OWNER AR session lifecycle. The shared `service` (one ARView /
        // ARSession) is started/stopped ONLY here, on the host. The per-direction
        // views (MeasureA/B/CView) swap on `style` WITHOUT tearing down this host,
        // so the session survives direction switches untouched.
        //
        // Previously each direction also called start()/stop() in its own
        // onAppear/onDisappear. On a style switch SwiftUI inserts the new direction
        // and removes the old one in an UNSPECIFIED order, so the outgoing view's
        // stop() (session.pause) could run *after* the incoming view's start()
        // (a no-op while `isRunning` is still true) — leaving the session paused
        // with nothing to restart it. That froze the camera on the last frame
        // while the rest of the UI stayed live. Owning lifecycle on the stable
        // host removes that race for every Precision⇄Minimal⇄Pro transition.
        .onAppear { service.start() }
        .onDisappear { service.stop() }
        // Backgrounding mid-measure must pause the AR session (camera release
        // + battery); returning resumes and ARKit relocalizes.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                service.start()
            case .background, .inactive:
                service.stop()
            @unknown default:
                break
            }
        }
    }

    /// True while the AR session is warming up (camera + world tracking starting).
    private var isInitializing: Bool {
        if case .initializing = service.tracking { return true }
        return false
    }

    /// Cold-start info overlay. On device the camera is black until ARKit's first
    /// tracked frame, and first-launch RealityKit/Metal warm-up briefly ties up the
    /// main thread — without context that reads as a *freeze*. This card explains
    /// the wait and coaches the motion ARKit needs to converge, turning dead time
    /// into guidance. It's a static card (not a lone spinner): if a momentary stall
    /// freezes the animation, the message still reads correctly.
    /// No-op in the Simulator (simulated backend reports `.normal`), so it never
    /// affects normal previews/screenshots; `-uiTrackingState initializing` forces
    /// it for verification.
    @ViewBuilder
    private var arLoadingOverlay: some View {
        if isInitializing {
            ZStack {
                Theme.cameraBG.ignoresSafeArea()
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(theme.accent.withA(0.18), lineWidth: 2)
                            .frame(width: 76, height: 76)
                        Icon("lidar", size: 34, weight: 1.8, color: theme.accent)
                        ProgressView()
                            .controlSize(.regular)
                            .tint(theme.accent)
                            .offset(y: 50) // sits just under the glyph ring
                    }
                    .frame(height: 96)

                    VStack(spacing: 7) {
                        Text("Starting AR session")
                            .font(Theme.sans(17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Move your device slowly so it can map the space. This takes a moment right after launch.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.ink2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
                .frame(maxWidth: 300)
                .background(
                    RoundedRectangle(cornerRadius: theme.r(22), style: .continuous)
                        .fill(Theme.glass)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.r(22), style: .continuous)
                        .strokeBorder(Theme.glassBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            }
            .transition(.opacity)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Starting AR session. Move your device slowly so it can map the space.")
        }
    }

    @ViewBuilder
    private var direction: some View {
        Group {
            switch style {
            case .precision: MeasureAView(service: service)
            case .minimal:   MeasureBView(service: service)
            case .pro:       MeasureCView(service: service)
            }
        }
        // Reserve real layout space for the floating tab bar so the controls are
        // never cropped by it. Camera/AR layers inside each direction keep their
        // own .ignoresSafeArea() and stay full-bleed — only the controls lift.
        // (Applied to `direction` only, NOT the ZStack, so the host's AR session
        // lifecycle in `body` is untouched.)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: TabBarMetrics.contentClearance)
        }
    }

    #if DEBUG
    /// Floating glass segmented picker for the HUD style, top-center, below the
    /// status bar. DEBUG-only design-review tool — never user-facing in Release.
    private var stylePicker: some View {
        HStack(spacing: 2) {
            ForEach(MeasureHUDStyle.allCases) { s in
                let on = s == style
                Text(s.label)
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(on ? Color.white : Theme.ink2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(on ? theme.accent.withA(0.9) : .clear)
                    )
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { style = s } }
                    .accessibilityLabel("\(s.label) HUD style")
                    .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.glass))
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        // Centered just below the notch; opacity-dimmed so it never fights the HUD.
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .allowsHitTesting(true)
    }
    #endif
}

#Preview {
    MeasureView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
