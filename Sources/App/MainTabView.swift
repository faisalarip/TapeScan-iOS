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
        Color.clear.frame(height: 64)
    }
}

// MARK: - Bottom tab bar

/// The design's dark glass bottom tab bar. Four equal items; the selected item
/// tints its glyph + label with the live accent and shows an accent-soft pill.
struct TabBar: View {
    @Environment(\.theme) private var theme
    @Binding var selection: AppTab

    var body: some View {
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
