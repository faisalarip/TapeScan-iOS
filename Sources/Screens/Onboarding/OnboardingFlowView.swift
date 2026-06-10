// OnboardingFlowView.swift — the 3-step onboarding coordinator.
//
// Ported 1:1 from onboarding.jsx (`OnbWelcome` → `OnbPermission` → `OnbCalibrate`)
// and the verified HTML reference (nav: welcome → permission → calibrate → measure).
//
// Flow:
//   • "Get Started"          (Welcome)    → advances to Permission
//   • "Allow Camera Access"  (Permission) → advances to Calibrate
//   • "Not now"              (Permission) → advances to Calibrate (camera optional in the prime)
//   • "Start Measuring"      (Calibrate)  → `appState.completeOnboarding()` → Main / Measure
//
// RootView should present `OnboardingFlowView()` for `AppPhase.onboarding`.
// Each step reads live tokens via `@Environment(\.theme)` and drives the flow
// through `AppState`; the shared `OnbDots` paging indicator threads through all three.

import SwiftUI

/// The three discrete onboarding steps, in order.
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case permission = 1
    case calibrate = 2
}

/// Top-level onboarding flow. Owns the current step and swaps the three screens
/// with a crossfade; the final "Start Measuring" CTA completes onboarding.
public struct OnboardingFlowView: View {
    @Environment(AppState.self) private var appState

    @State private var step: OnboardingStep = .welcome

    public init() {}

    public var body: some View {
        ZStack {
            switch step {
            case .welcome:
                OnbWelcomeView { advance(to: .permission) }
                    .transition(.opacity)
            case .permission:
                OnbPermissionView { advance(to: .calibrate) }
                    .transition(.opacity)
            case .calibrate:
                OnbCalibrateView { appState.completeOnboarding() }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: step)
    }

    private func advance(to next: OnboardingStep) {
        step = next
    }
}

// MARK: - Paging dots

/// The onboarding paging indicator: `n` dots, the active one stretched to a pill.
/// Active dot is 22×7 accent; the rest are 7×7 white@0.25 (source `Dots`).
struct OnbDots: View {
    @Environment(\.theme) private var theme
    let count: Int
    let active: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == active ? theme.accent : Color.white.opacity(0.25))
                    .frame(width: i == active ? 22 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: active)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(active + 1) of \(count)")
    }
}

#Preview {
    OnboardingFlowView()
        .environment(AppState())
        .installTheme(Theme(accent: AccentOption.blue.color))
}
