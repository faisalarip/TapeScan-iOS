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

public struct MeasureView: View {
    @Environment(\.theme) private var theme

    @State private var style: MeasureHUDStyle
    /// Shared AR backend for whichever direction is active.
    @State private var service: any ARMeasureService

    @MainActor
    public init() {
        _service = State(initialValue: MeasureServiceFactory.make())
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

    public var body: some View {
        ZStack(alignment: .top) {
            direction
            #if DEBUG
            stylePicker
            #endif
        }
        .background(Theme.cameraBG.ignoresSafeArea())
    }

    @ViewBuilder
    private var direction: some View {
        switch style {
        case .precision: MeasureAView(service: service)
        case .minimal:   MeasureBView(service: service)
        case .pro:       MeasureCView(service: service)
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
