// HistoryView.swift — saved-measurements library (History tab).
//
// Real data: a SwiftData @Query over live (non-tombstoned) MeasurementRecords,
// grouped by capture day (Today / Yesterday / date), live-filtered by the
// search field. Rows expose delete via context menu (tombstone — sync
// propagates it in M7). Visual design unchanged from the verified port:
// large title, focusable search, grouped DRow sections with colored icon
// tiles (distance/area = accent, volume = purple, angle = amber).

import SwiftUI
import SwiftData

public struct HistoryView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(MeasurementRecord.visibleDescriptor()) private var records: [MeasurementRecord]

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
                ForEach(groups, id: \.header) { group in
                    DListSection(header: group.header) {
                        ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, record in
                            row(record, last: index == group.rows.count - 1)
                        }
                    }
                }

                if records.isEmpty {
                    noMeasurementsState
                } else if groups.isEmpty {
                    noResultsState
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func row(_ record: MeasurementRecord, last: Bool) -> some View {
        let detailText = detail(for: record)
        DRow(icon: icon(for: record.mode),
             iconBackground: iconBackground(for: record.mode),
             title: record.name,
             subtitle: record.mode.label,
             detail: detailText,
             last: last,
             action: {}) {
            Chevron()
        }
        .accessibilityLabel("\(record.name), \(record.mode.label), \(detailText)")
        .contextMenu {
            Button(role: .destructive) {
                delete(record)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var noMeasurementsState: some View {
        VStack(spacing: 8) {
            Icon("distance", size: 30, weight: 1.8, color: Theme.ink3)
            Text("No measurements yet")
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.ink2)
            Text("Finish a measurement on the Measure tab\nand it will appear here.")
                .font(Theme.sans(13))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var noResultsState: some View {
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

    // MARK: - Data shaping

    /// Records filtered by the search needle, grouped by capture day in
    /// newest-first order (the query is already sorted newest-first).
    private var groups: [(header: String, rows: [MeasurementRecord])] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = needle.isEmpty
            ? records
            : records.filter {
                ($0.name + " " + $0.mode.label).lowercased().contains(needle)
            }

        let calendar = Calendar.current
        var ordered: [(header: String, rows: [MeasurementRecord])] = []
        for record in filtered {
            let header: String
            if calendar.isDateInToday(record.createdAt) {
                header = "Today"
            } else if calendar.isDateInYesterday(record.createdAt) {
                header = "Yesterday"
            } else {
                header = record.createdAt.formatted(date: .abbreviated, time: .omitted)
            }
            if let i = ordered.firstIndex(where: { $0.header == header }) {
                ordered[i].rows.append(record)
            } else {
                ordered.append((header, [record]))
            }
        }
        return ordered
    }

    private func icon(for mode: MeasureMode) -> String {
        switch mode {
        case .distance: return "distance"
        case .area:     return "room"
        case .volume:   return "volume"
        case .angle:    return "angle"
        }
    }

    /// Icon tile fill: accent-soft for distance/area, solid purple for volume,
    /// solid amber for angle — mirroring the design's `iconBg` overrides.
    private func iconBackground(for mode: MeasureMode) -> Color? {
        switch mode {
        case .distance, .area: return nil
        case .volume:          return Theme.purple.withA(0.9)
        case .angle:           return Theme.amber.withA(0.9)
        }
    }

    /// Primary value of the stored result, formatted for the active unit.
    private func detail(for record: MeasurementRecord) -> String {
        guard let result = try? record.decodedResult() else { return "—" }
        switch record.mode {
        case .distance: return UnitFormat.lengthFractional(result.totalLength, unit: theme.unit)
        case .area:     return UnitFormat.area(result.area ?? 0, theme.unit)
        case .volume:   return UnitFormat.volume(result.volume ?? 0, theme.unit)
        case .angle:    return UnitFormat.angle(result.angleDegrees ?? 0)
        }
    }

    private func delete(_ record: MeasurementRecord) {
        record.markDeleted()
        do {
            try modelContext.save()
        } catch {
            appState.presentAlert(title: "Couldn't delete",
                                  message: error.localizedDescription)
        }
    }
}

#Preview("History · empty") {
    HistoryView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
        .modelContainer(ModelContainerFactory.makeInMemory())
}

#Preview("History · seeded") {
    let container = ModelContainerFactory.makeInMemory()
    let context = ModelContext(container)
    for (name, mode, points) in [
        ("Living room", MeasureMode.area,
         [SIMD3<Float>(0, 0, 0), .init(4, 0, 0), .init(4, 0, 3), .init(0, 0, 3)]),
        ("Sofa width", .distance, [.init(0, 0, 0), .init(2.18, 0, 0)]),
    ] {
        let worldPoints = points.map { WorldPoint(position: $0) }
        if let record = try? MeasurementRecord(
            name: name, mode: mode, points: worldPoints,
            result: MeasureMath.result(mode: mode, points: points)) {
            context.insert(record)
        }
    }
    try? context.save()
    return HistoryView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
        .modelContainer(container)
}
