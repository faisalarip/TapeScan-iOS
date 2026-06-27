// OnbCalibrateView.swift — onboarding step 3 · CALIBRATE / PLANE DETECTION.
//
// Ported 1:1 from onboarding.jsx `OnbCalibrate`:
//   • Full-bleed live camera stand-in: CameraBackdrop(scan:) + FeaturePoints.
//   • A "FLOOR DETECTED" callout pinned at 64% of the frame.
//   • Top instruction block: mono kicker "CALIBRATE", 25-pt headline, sub-copy.
//   • Bottom deck: a tracking-strength row (green blinking dot + point count +
//     5 signal bars), paging dots (active 2), and the terminal "Start Measuring"
//     CTA which completes onboarding → Measure.

import SwiftUI

/// Onboarding calibration step. `onFinish` completes onboarding (→ Measure).
struct OnbCalibrateView: View {
    @Environment(\.theme) private var theme
    // Analytics seam (no-op until the Firebase SDK is added by the owner). Used to
    // fire `onboarding_completed` and stamp the matching user property when the
    // user taps "Start Measuring". appState is injected here (and in #Preview).
    @Environment(AppState.self) private var appState

    var onFinish: () -> Void = {}

    /// Signal-bar opacities — 4 strong + 1 faint (source `[1,1,1,1,0.3]`).
    private let bars: [Double] = [1, 1, 1, 1, 0.3]

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height

            ZStack {
                // live camera stand-in with scan sweep
                CameraBackdrop(accent: theme.accent, scan: true)
                FeaturePoints(accent: theme.accent)

                // detected-plane callout at 64% height
                floorDetectedCallout
                    .position(x: geo.size.width / 2, y: h * 0.64)

                // top instruction block (top inset 100)
                VStack(spacing: 0) {
                    instructions
                        .padding(.top, 100)
                    Spacer(minLength: 0)
                }

                // bottom deck pinned to the safe-area bottom
                VStack {
                    Spacer(minLength: 0)
                    bottomDeck
                        .padding(.horizontal, 22)
                        .padding(.bottom, 38)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Floor-detected callout

    private var floorDetectedCallout: some View {
        HStack(spacing: 7) {
            Icon("check", size: 15, weight: 2.6, color: .white)
            Text("FLOOR DETECTED")
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(theme.accent.withA(0.92))
        )
        .shadow(color: theme.accent.withA(0.5), radius: 10, y: 6)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Top instructions

    private var instructions: some View {
        VStack(spacing: 0) {
            Text("CALIBRATE")
                .font(Theme.mono(11))
                .tracking(3)
                .foregroundStyle(theme.accent)

            Text("Pan slowly to map the room")
                .font(Theme.sans(25, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.7), radius: 5, y: 2)
                .padding(.top, 10)

            Text("Move your phone in a slow arc until surfaces lock in.")
                .font(Theme.sans(14.5))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom deck

    private var bottomDeck: some View {
        VStack(spacing: 16) {
            trackingRow
            OnbDots(count: 3, active: 2)
            PrimaryButton(title: "Start Measuring", icon: "ruler2") {
                // Onboarding terminal step — the user is heading into Measure.
                // Log the funnel completion and flip the durable user property so
                // GA4 can segment by whether a user finished onboarding. Fired here
                // (rather than where `appState.completeOnboarding()` lives in the
                // parent) so the event is tied to the actual CTA tap.
                appState.analytics.log(AnalyticsEventName.onboardingCompleted)
                appState.analytics.setUserProperty("true", for: .onboardingCompleted)
                onFinish()
            }
            .accessibilityLabel("Start measuring")
        }
    }

    /// Tracking-strength row: blinking success dot + point count + signal bars.
    private var trackingRow: some View {
        HStack(spacing: 12) {
            StatusDot(color: Theme.successGreen, blink: true)

            Text("Tracking strong · 142 points")
                .font(Theme.sans(13.5))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 3) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, opacity in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(theme.accent.opacity(opacity))
                        .frame(width: 4, height: 12)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                        .fill(Color(.sRGB, red: 13/255, green: 14/255, blue: 17/255, opacity: 0.82))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tracking strong, 142 points")
    }
}

#Preview {
    OnbCalibrateView()
        .environment(AppState())
        .installTheme(Theme(accent: AccentOption.blue.color))
}
