// OnbWelcomeView.swift — onboarding step 1 · WELCOME.
//
// Ported 1:1 from onboarding.jsx `OnbWelcome`:
//   • 392-pt AR hero: CameraBackdrop + FeaturePoints + pulsing Reticle, a
//     measure polyline with two endpoint nodes, a `2.34 m` measure pill, and a
//     bottom fade into the screen background.
//   • Copy block: mono kicker "TAPEMEASURE AR PRO", 30-pt headline, three
//     feature rows (accent-soft 38×38 icon tiles).
//   • Footer: paging dots (active 0) + "Get Started" primary CTA.

import SwiftUI

/// Onboarding welcome hero. `onContinue` advances the flow to the permission step.
struct OnbWelcomeView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    var onContinue: () -> Void = {}

    /// Uppercased brand for the eyebrow; blank brand falls back to "TAPEMEASURE".
    private var brandName: String {
        let trimmed = appState.brand.trimmingCharacters(in: .whitespaces)
        return (trimmed.isEmpty ? "TapeMeasure" : trimmed).uppercased()
    }

    /// (icon, label) for the three feature rows — source order preserved.
    private let features: [(icon: String, label: String)] = [
        ("distance", "Multi-point distance, area & volume"),
        ("scan",     "Guided room scan → floor plan"),
        ("cube3d",   "Export to glTF, SVG & PNG"),
    ]

    var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                hero
                copy
                Spacer(minLength: 0)
                footer
            }
        }
    }

    // MARK: - Hero (height 392)

    private var hero: some View {
        // Source viewBox is 402×392; map the polyline / pill to the live width.
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 392
            // polyline endpoints in 402×392 space
            let p1 = CGPoint(x: 90.0 / 402.0 * w, y: 250.0 / 392.0 * h)
            let p2 = CGPoint(x: 300.0 / 402.0 * w, y: 278.0 / 392.0 * h)

            ZStack {
                CameraBackdrop(accent: theme.accent, plane: true)
                FeaturePoints(accent: theme.accent)
                Reticle(accent: theme.accent, pulse: true)

                // measure line between two placed points
                Path { p in
                    p.move(to: p1)
                    p.addLine(to: p2)
                }
                .stroke(theme.accent, lineWidth: 2)

                endpointNode.position(p1)
                endpointNode.position(p2)

                // measure value pill — top 232, horizontally centered
                Text(UnitFormat.length(2.34, theme.unit))
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(theme.accent.withA(0.92))
                    )
                    .fixedSize()
                    .position(x: w / 2, y: 232 + 11)   // top 232 + half pill height

                // fade hero into screen background (transparent 55% → screenBG)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.55),
                        .init(color: Theme.screenBG, location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(height: 392)
        .clipped()
    }

    /// One endpoint marker: dark fill, accent ring (r 6, sw 2).
    private var endpointNode: some View {
        Circle()
            .fill(Color(.sRGB, red: 10/255, green: 12/255, blue: 15/255, opacity: 0.85))
            .frame(width: 12, height: 12)
            .overlay(Circle().strokeBorder(theme.accent, lineWidth: 2))
    }

    // MARK: - Copy

    private var copy: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand-derived eyebrow: "{BRAND} AR PRO", uppercased. With the default
            // brand this renders "TAPEMEASURE AR PRO" — identical to the source.
            Text("\(brandName) AR PRO")
                .font(Theme.mono(11))
                .tracking(3)
                .foregroundStyle(theme.accent)
                .padding(.bottom, 10)

            Text("Measure anything,\nright from your phone.")
                .font(Theme.sans(30, weight: .bold))
                .tracking(-0.6)
                .lineSpacing(30 * 0.12)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(features, id: \.label) { feat in
                    HStack(spacing: 13) {
                        ZStack {
                            RoundedRectangle(cornerRadius: theme.r(11), style: .continuous)
                                .fill(theme.accentSoft)
                                .frame(width: 38, height: 38)
                            Icon(feat.icon, size: 20, weight: 1.8, color: theme.accent)
                        }
                        Text(feat.label)
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.ink2)
                    }
                }
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 26)
        .padding(.top, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 18) {
            OnbDots(count: 3, active: 0)
            PrimaryButton(title: "Get Started") { onContinue() }
                .accessibilityLabel("Get started")
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 38)
    }
}

#Preview {
    OnbWelcomeView()
        .environment(AppState())
        .installTheme(Theme(accent: AccentOption.blue.color))
}
