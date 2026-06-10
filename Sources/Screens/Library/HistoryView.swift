// HistoryView.swift — saved-measurements library (History tab).
//
// Ported 1:1 from the design's `History` (support.jsx + the verified HTML
// reference). A large title, a focusable search field that live-filters the
// rows, and Today / Yesterday grouped sections of measurement rows. Each row
// carries a colored icon tile (distance/area = accent, volume = purple,
// angle = amber) and a mono detail value formatted for the active unit system.
//
// This is the *content* of the History tab; the bottom tab bar is owned by the
// `MainTabView` shell (per the screen-agent contract), so it is not drawn here.

import SwiftUI

public struct HistoryView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    public init() {}

    public var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                title
                searchField
                list
            }
        }
    }

    // MARK: - Large title

    private var title: some View {
        HStack {
            Text("History")
                .font(Theme.sans(30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Icon("search", size: 17, weight: 2, color: Theme.ink3)
            TextField("",
                      text: $query,
                      prompt: Text("Search measurements").foregroundColor(Theme.ink3))
                .font(Theme.sans(14.5))
                .foregroundStyle(Theme.ink)
                .tint(theme.accent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .submitLabel(.search)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: theme.r(12), style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.r(12), style: .continuous)
                .strokeBorder(searchFocused ? theme.accent.withA(0.8) : Color.clear,
                              lineWidth: 1.5)
        )
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search measurements")
    }

    // MARK: - Grouped list

    private var list: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(filteredGroups) { group in
                    DListSection(header: group.header) {
                        ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                            DRow(icon: row.icon,
                                 iconBackground: row.iconBackground(theme),
                                 title: row.title,
                                 subtitle: row.subtitle,
                                 detail: row.detail(unit: theme.unit),
                                 last: index == group.rows.count - 1,
                                 action: {}) {
                                Chevron()
                            }
                            .accessibilityLabel("\(row.title), \(row.subtitle), \(row.detail(unit: theme.unit))")
                        }
                    }
                }

                if filteredGroups.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Icon("search", size: 30, weight: 1.8, color: Theme.ink3)
            Text("No measurements found")
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.ink2)
            Text("Try a different search term")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    // MARK: - Filtering

    /// Sections with their rows filtered by the search needle; empty sections
    /// are dropped so the layout collapses cleanly (matching the HTML behavior).
    private var filteredGroups: [HistoryGroup] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return HistoryGroup.all }
        return HistoryGroup.all.compactMap { group in
            let rows = group.rows.filter { $0.matches(needle) }
            return rows.isEmpty ? nil : HistoryGroup(header: group.header, rows: rows)
        }
    }
}

// MARK: - Model

/// A single saved measurement displayed as a history row.
struct HistoryItem: Identifiable {
    enum Kind { case distance(Double), area(Double), volume(Double), angle(Double) }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String

    var icon: String {
        switch kind {
        case .distance: return "distance"
        case .area:     return "room"     // area items are floor plans → room glyph (per source)
        case .volume:   return "volume"
        case .angle:    return "angle"
        }
    }

    /// Icon tile fill: accent-soft for distance/area, solid purple for volume,
    /// solid amber for angle — mirroring the source `iconBg` overrides.
    func iconBackground(_ theme: Theme) -> Color? {
        switch kind {
        case .distance, .area: return nil          // → accentSoft + accent glyph
        case .volume:          return Theme.purple.withA(0.9)
        case .angle:           return Theme.amber.withA(0.9)
        }
    }

    /// Detail value formatted for the active unit system.
    func detail(unit: MeasureUnit) -> String {
        switch kind {
        case .distance(let m): return UnitFormat.length(m, unit)
        case .area(let m2):    return UnitFormat.area(m2, unit)
        case .volume(let m3):  return UnitFormat.volume(m3, unit)
        case .angle(let deg):  return UnitFormat.angle(deg)
        }
    }

    func matches(_ needle: String) -> Bool {
        (title + " " + subtitle).lowercased().contains(needle)
    }
}

/// A dated group of history items ("Today", "Yesterday").
struct HistoryGroup: Identifiable {
    let header: String
    let rows: [HistoryItem]
    var id: String { header }

    /// The seeded data set from the design.
    static let all: [HistoryGroup] = [
        HistoryGroup(header: "Today", rows: [
            HistoryItem(id: "r0", kind: .area(29.6),     title: "Living room",    subtitle: "Area · floor plan"),
            HistoryItem(id: "r1", kind: .distance(2.18), title: "Sofa width",     subtitle: "Distance"),
        ]),
        HistoryGroup(header: "Yesterday", rows: [
            HistoryItem(id: "r2", kind: .volume(0.42),    title: "Storage box",    subtitle: "Volume"),
            HistoryItem(id: "r3", kind: .angle(32.5),     title: "Roof pitch",     subtitle: "Angle"),
            HistoryItem(id: "r4", kind: .distance(2.04),  title: "Doorway height", subtitle: "Distance"),
        ]),
    ]
}

#Preview("History · Metric") {
    HistoryView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}

#Preview("History · Imperial") {
    let state = AppState()
    state.unit = .imperial
    return HistoryView()
        .environment(state)
        .environment(\.theme, Theme(state))
}
