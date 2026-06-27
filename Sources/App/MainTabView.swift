// MainTabView.swift — the main tabbed shell (Measure / Rooms / History / Settings).
//
// Replaces RootView's `MainPlaceholderView` for `AppPhase.main`. Owns the bottom
// tab bar (the design's dark glass `TabBar`) and switches the four tab hosts on
// `AppState.selectedTab`:
//
//   • Measure  → MeasureView   (3 AR directions via its in-screen HUD picker)
//   • Rooms    → RoomsView     (RoomScan → Export → Paywall)
//   • History  → HistoryView
//   • Settings → SettingsView
//
// Measure & Rooms render full-bleed over the camera backdrop, so the tab bar
// floats on top of them; History & Settings draw their own screen background and
// reserve bottom padding for the bar. The bar binds straight to the observable
// `AppState`, so tab selection is part of the single source of truth.

import SwiftUI

/// The main tabbed experience. Presented by ``RootView`` for ``AppPhase/main``.
public struct MainTabView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        @Bindable var appState = appState

        return ZStack(alignment: .bottom) {
            Theme.screenBG.ignoresSafeArea()

            // Active tab content.
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating bottom tab bar.
            TabBar(selection: $appState.selectedTab)
        }
        // Fire a GA4 `screen_view` whenever the user switches tabs. SwiftUI has no
        // automatic screen_view, and AppState.selectedTab is the single source of
        // truth for which of Measure/Rooms/History/Settings is on screen — so one
        // observer here covers all four. The seam is a no-op when collection is
        // disabled or the SDK is absent, so this is always safe to call.
        .onChange(of: appState.selectedTab) { _, newTab in
            appState.analytics.log(
                AnalyticsEventName.screenView,
                [AnalyticsParam.screenName: .string(newTab.rawValue)]
            )
        }
        // `.onChange` skips the initial value, so log the FIRST tab (the
        // cold-start landing screen) once here — together they emit a
        // `screen_view` for every tab the user actually lands on.
        .onAppear {
            appState.analytics.log(
                AnalyticsEventName.screenView,
                [AnalyticsParam.screenName: .string(appState.selectedTab.rawValue)]
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.selectedTab {
        case .measure:  MeasureView()
        case .rooms:    RoomsView()
        case .history:  HistoryView().safeAreaInset(edge: .bottom) { tabBarSpacer }
        case .settings: SettingsView().safeAreaInset(edge: .bottom) { tabBarSpacer }
        }
    }

    /// Reserves room under the scrollable tabs so the floating bar never covers
    /// the last row. Measure/Rooms are full-bleed and intentionally bleed under it.
    private var tabBarSpacer: some View {
        Color.clear.frame(height: TabBarMetrics.scrollSpacer)
    }
}

// MARK: - Bottom tab bar

/// The design's dark glass bottom tab bar. Four equal items; the selected item
/// tints its glyph + label with the live accent and shows an accent-soft pill.
struct TabBar: View {
    @Environment(\.theme) private var theme
    @Binding var selection: AppTab
    /// Morph namespace so the selected accent pill slides between tabs.
    @Namespace private var pillNS

    var body: some View {
        if #available(iOS 26.0, *) {
            floatingCapsule
        } else {
            legacyDeck
        }
    }

    // MARK: iOS 26 — floating Liquid Glass capsule

    /// The iOS-26 system silhouette: a glass capsule that floats above the home
    /// indicator with side margins. One `.regular` glass over the whole bar stays
    /// legible over the live AR camera and avoids glass-on-glass artifacts.
    @available(iOS 26.0, *)
    private var floatingCapsule: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                FloatingTabItem(tab: tab, selected: tab == selection, pillNS: pillNS) {
                    withAnimation(.bouncy(duration: 0.34)) { selection = tab }
                }
            }
        }
        .padding(6)
        .glassEffect(.regular.interactive())
        .padding(.horizontal, 16)
        .padding(.bottom, TabBarMetrics.floatingBottomGap)
        // Deliberately NO .ignoresSafeArea — the capsule floats ABOVE the safe area.
        .accessibilityElement(children: .contain)
    }

    // MARK: iOS 17–25 — existing solid deck (verbatim fallback)

    private var legacyDeck: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                TabBarItem(tab: tab, selected: tab == selection) {
                    withAnimation(.easeOut(duration: 0.18)) { selection = tab }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            Rectangle()
                .fill(Theme.deck)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
        .accessibilityElement(children: .contain)
    }
}

/// iOS 26 capsule item; the selected accent pill slides between tabs via
/// `matchedGeometryEffect`. Idle glyph/label use ink/ink2 (not ink3) for
/// legibility over a bright, moving camera feed behind the glass.
@available(iOS 26.0, *)
private struct FloatingTabItem: View {
    @Environment(\.theme) private var theme
    let tab: AppTab
    let selected: Bool
    let pillNS: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    if selected {
                        Capsule()
                            .fill(theme.accentSoft)
                            .frame(width: 52, height: 32)
                            .matchedGeometryEffect(id: "tabpill", in: pillNS)
                    }
                    Icon(tab.iconName, size: 22, weight: 1.9,
                         color: selected ? theme.accent : Theme.ink)
                }
                .frame(height: 32)

                Text(tab.title)
                    .font(Theme.sans(10.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? theme.accent : Theme.ink2)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Tab bar metrics

/// Single source of truth for how much bottom space the tab bar occupies, so
/// full-bleed Measure/Rooms controls and scrollable History/Settings clear it.
/// Branches per-OS: the iOS 26 floating capsule respects the safe area and floats
/// with a bottom gap (taller above-safe-area footprint), whereas the iOS 17–25
/// deck bleeds under the home indicator.
enum TabBarMetrics {
    /// Gap between the floating capsule and the home indicator (iOS 26 only).
    static let floatingBottomGap: CGFloat = 12
    /// Comfort gap so controls never kiss the bar.
    private static let comfortGap: CGFloat = 12
    /// Legacy deck (17–25): item minHeight 44 + .top 8 + .bottom 6 = 58.
    private static let legacyOccupied: CGFloat = 58
    /// Floating capsule (26): item ~44 + 6·2 padding ≈ 56 → 60, plus the bottom gap.
    private static let floatingOccupied: CGFloat = 60 + floatingBottomGap // 72

    /// Bottom clearance the full-bleed Measure/Rooms controls reserve.
    static var contentClearance: CGFloat {
        if #available(iOS 26.0, *) { return floatingOccupied + comfortGap } // 84
        return legacyOccupied + comfortGap                                  // 70
    }
    /// Spacer reserved under scrollable tabs (History/Settings).
    static var scrollSpacer: CGFloat {
        if #available(iOS 26.0, *) { return floatingOccupied + 4 }          // 76
        return 64
    }
}

/// A single tab-bar cell: accent-soft pill behind the glyph when selected,
/// accent glyph + label; ink3 when idle. 44pt min tap target.
private struct TabBarItem: View {
    @Environment(\.theme) private var theme
    let tab: AppTab
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    if selected {
                        RoundedRectangle(cornerRadius: theme.r(11), style: .continuous)
                            .fill(theme.accentSoft)
                            .frame(width: 52, height: 30)
                    }
                    Icon(tab.iconName, size: 22, weight: 1.9,
                         color: selected ? theme.accent : Theme.ink3)
                }
                .frame(height: 30)

                Text(tab.title)
                    .font(Theme.sans(10.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? theme.accent : Theme.ink3)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
        .installTheme(Theme(accent: AccentOption.blue.color))
}
