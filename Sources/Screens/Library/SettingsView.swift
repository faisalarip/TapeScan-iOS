// SettingsView.swift — the reskin surface + live tweak panel (Settings tab).
//
// Ported from the design's `Settings` (support.jsx + the verified HTML
// reference) and extended with the explicitly-requested Theme group so the
// white-label template is *visibly* reskinnable from inside the running app:
//   • Pro upsell card (accent gradient → would route to the paywall).
//   • Measurement: Units (segmented → AppState.unit), Point snapping (toggle),
//     Precision (row showing ±4 mm / ±2 cm derived from the LiDAR flag).
//   • AR Engine: LiDAR depth (toggle → AppState.lidar, re-themes the whole app),
//     Plane detection (segmented, local).
//   • Theme: accent swatch picker (5 options → AppState.accent) + a brand-name
//     field (→ AppState.brand). Mutating either re-themes every screen live.
//
// Everything recomputes live because the controls bind straight to the
// `@Observable` AppState; `Theme(appState)` is rebuilt by the root on change.

import SwiftUI

public struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    // Local interactive state for controls that are not global tweaks.
    @State private var pointSnapping = true
    @State private var planeDetection: PlaneMode = .all
    @State private var showPaywall = false

    public init() {}

    private enum PlaneMode: String, CaseIterable, Hashable { case floor = "Floor", all = "All" }

    public var body: some View {
        // Bind directly to the observable app state so segmented/toggle controls
        // mutate the source of truth and the UI re-themes immediately.
        @Bindable var appState = appState

        return ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                title

                ScrollView {
                    VStack(spacing: 18) {
                        proUpsell
                        measurementGroup(unit: $appState.unit)
                        arEngineGroup(lidar: $appState.lidar)
                        themeGroup(accent: appState.accent,
                                   setAccent: { appState.accent = $0 },
                                   brand: $appState.brand)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            // The Settings card is always a proactive upsell, so the headline must
            // not falsely claim the free quota is spent.
            PaywallView(context: .proactive(freeExportsLeft: appState.freeExportsLeft)) {
                showPaywall = false
            }
            .environment(appState)
            .installTheme(Theme(appState))
        }
    }

    // MARK: - Large title

    private var title: some View {
        HStack {
            Text("Settings")
                .font(Theme.sans(30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Pro upsell

    private var proUpsell: some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.r(12), style: .continuous)
                        .fill(Color.white.opacity(0.2))
                    Icon("cube3d", size: 24, weight: 1.8, color: .white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(appState.brand) Pro")
                        .font(Theme.sans(16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("glTF export · unlimited rooms")
                        .font(Theme.sans(12.5))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                Spacer(minLength: 8)

                Text("Upgrade")
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(Color(hex: "#111111"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                    .fill(LinearGradient(
                        colors: [theme.accent.withA(0.9), theme.accent.withA(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to \(appState.brand) Pro")
    }

    // MARK: - Measurement

    private func measurementGroup(unit: Binding<MeasureUnit>) -> some View {
        DListSection(header: "Measurement") {
            DRow(icon: "ruler2", title: "Units", accessory: {
                IOSSegmented(options: MeasureUnit.allCases,
                             selection: unit) { $0.title }
                    .accessibilityLabel("Units")
            })
            DRow(icon: "pin", title: "Point snapping", accessory: {
                IOSToggle(isOn: $pointSnapping)
                    .accessibilityLabel("Point snapping")
                    .accessibilityValue(pointSnapping ? "On" : "Off")
            })
            // Precision is derived from the LiDAR flag: ±4 mm vs ±2 cm.
            DRow(icon: "distance",
                 title: "Precision",
                 detail: theme.precisionBadge,
                 last: true,
                 action: {}) {
                Chevron()
            }
            .accessibilityLabel("Precision \(theme.precisionBadge)")
        }
    }

    // MARK: - AR Engine

    private func arEngineGroup(lidar: Binding<Bool>) -> some View {
        DListSection(header: "AR Engine") {
            DRow(icon: "lidar",
                 title: "LiDAR depth",
                 subtitle: lidar.wrappedValue
                    ? "Auto · device supported"
                    : "Off · visual-inertial fallback", accessory: {
                IOSToggle(isOn: lidar)
                    .accessibilityLabel("LiDAR depth")
                    .accessibilityValue(lidar.wrappedValue ? "On" : "Off")
            })
            DRow(icon: "grid", title: "Plane detection", last: true, accessory: {
                IOSSegmented(options: PlaneMode.allCases,
                             selection: $planeDetection) { $0.rawValue }
                    .accessibilityLabel("Plane detection")
            })
        }
    }

    // MARK: - Theme (reskin surface)

    private func themeGroup(accent: AccentOption,
                            setAccent: @escaping (AccentOption) -> Void,
                            brand: Binding<String>) -> some View {
        DListSection(header: "Theme") {
            // Accent swatch picker — 5 options in design order.
            DRow(icon: "grid", title: "Accent color", accessory: {
                HStack(spacing: 10) {
                    ForEach(AccentOption.allCases) { option in
                        AccentSwatch(option: option,
                                     selected: accent == option) {
                            setAccent(option)
                        }
                    }
                }
            })
            // Brand-name field — drives the wordmark / Pro card / auth lockup.
            DRow(icon: "ruler2", title: "Brand name", last: true, accessory: {
                BrandField(brand: brand)
            })
        }
    }
}

// MARK: - Accent swatch

/// A single tappable accent color swatch with a selected ring + check.
private struct AccentSwatch: View {
    @Environment(\.theme) private var theme
    let option: AccentOption
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(option.color)
                    .frame(width: 26, height: 26)
                if selected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: 32, height: 32)
                    Icon("check", size: 14, weight: 2.6, color: .white)
                }
            }
            .frame(width: 36, height: 36)        // 44pt row height keeps the target tappable
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.name) accent")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Brand field

/// Inline trailing text field bound to `AppState.brand`. Blank input falls back
/// so the wordmark never renders empty.
private struct BrandField: View {
    @Environment(\.theme) private var theme
    @Binding var brand: String
    @FocusState private var focused: Bool

    var body: some View {
        TextField("",
                  text: $brand,
                  prompt: Text(AppState.defaultBrand).foregroundColor(Theme.ink3))
            .font(Theme.sans(14.5, weight: .medium))
            .foregroundStyle(Theme.ink)
            .tint(theme.accent)
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
            .focused($focused)
            .frame(maxWidth: 150)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: theme.r(8), style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(8), style: .continuous)
                    .strokeBorder(focused ? theme.accent.withA(0.8) : Color.white.opacity(0.10),
                                  lineWidth: focused ? 1.5 : 1)
            )
            .onSubmit { normalize() }
            .onChange(of: focused) { _, isFocused in if !isFocused { normalize() } }
            .accessibilityLabel("Brand name")
    }

    /// Collapse all-whitespace input back to the default brand.
    private func normalize() {
        if brand.trimmingCharacters(in: .whitespaces).isEmpty { brand = AppState.defaultBrand }
    }
}

#Preview("Settings · LiDAR + Blue") {
    SettingsView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}

#Preview("Settings · Fallback + Violet") {
    let state = AppState()
    state.lidar = false
    state.accent = .violet
    return SettingsView()
        .environment(state)
        .environment(\.theme, Theme(state))
}
