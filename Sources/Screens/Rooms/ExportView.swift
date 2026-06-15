// ExportView.swift — floor-plan export with format selection + free-export quota.
// Ported 1:1 from support.jsx `ExportScreen` + the verified HTML reference.
//
// Sections:
//   • header: "Export" / "Apartment · 4 rooms" + close
//   • amber quota meter — "N of 3 free exports left" reading AppState.freeExportsLeft;
//     bars fill the first N segments (amber), rest dim. Tapping it opens the Paywall.
//   • floor-plan preview card (FLOOR PLAN · METRIC/IMPERIAL + area chip)
//   • format grid: glTF / SVG / PNG / PDF cards, each toggleable (selected = accent)
//   • include toggles: Dimensions / Furniture & openings / Grid & scale bar
//   • CTA: when quota > 0 → "Export N files" (N = enabled formats), decrements quota,
//          and at 0 presents the Paywall. When quota == 0 → dimmed "Upgrade to export"
//          which presents the Paywall directly.
//
// The quota is the single source of truth on AppState; exporting mutates it so the
// whole app (and a re-entered Export screen) reflects the spent quota.

import SwiftUI

public struct ExportView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    /// The room being exported; nil only in previews (falls back to .sample).
    private let room: RoomRecord?
    /// Close handler (the X). Routes back to the Rooms list.
    private let onClose: () -> Void

    private static let freeTotal = 3

    /// A selectable export format card backed by a real ExportFormat.
    private struct Format: Identifiable {
        let format: ExportFormat
        var on: Bool
        var id: String { format.id }
    }

    @State private var formats: [Format] = [
        Format(format: .pdf, on: true),
        Format(format: .png, on: true),
        Format(format: .svg, on: false),
        Format(format: .dxf, on: false),
        Format(format: .csv, on: false),
        Format(format: .gltf, on: false),
        Format(format: .usdz, on: false),
    ]

    @State private var includeDimensions = true
    @State private var includeFurniture = true
    @State private var includeGrid = false

    @State private var showPaywall = false
    @State private var showPlanEditor = false
    @State private var isExporting = false
    /// Generated files awaiting the share sheet.
    @State private var shareURLs: [URL] = []
    @State private var showShareSheet = false
    @State private var exportService = ExportService()

    public init(room: RoomRecord? = nil, onClose: @escaping () -> Void = {}) {
        self.room = room
        self.onClose = onClose
    }

    // MARK: - Derived

    /// The plan rendered + exported. Previews (room == nil) use the fixture.
    private var plan: FloorPlanModel {
        if let room, let decoded = try? room.decodedPlan() { return decoded }
        #if DEBUG
        return .sample
        #else
        return FloorPlanModel(walls: [], openings: [], rooms: [],
                              widthMeters: 0, heightMeters: 0,
                              capturedAt: Date(timeIntervalSince1970: 0))
        #endif
    }

    private var left: Int { max(0, min(Self.freeTotal, appState.freeExportsLeft)) }
    /// Locked only when the user is not Pro AND has no free exports remaining.
    /// A successful purchase/restore sets `isPro`, which unlocks export here.
    private var locked: Bool { !appState.isPro && left <= 0 }
    private var enabledCount: Int { formats.filter(\.on).count }

    public var body: some View {
        // Background bleeds full-screen; content is laid out inside the device
        // safe area via the key window's real insets. iOS 26 `.fullScreenCover`
        // doesn't hand its content the device insets (see `coverSafeAreaPadding`).
        ZStack(alignment: .top) {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                quotaMeter
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                preview
                    .padding(.horizontal, 18)
                formatGrid
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                includeToggles
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                Spacer(minLength: 14)
                ctaBar
            }
            .coverSafeAreaPadding(appState.safeAreaInsets)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            // Context-aware copy: at 0 free exports the canonical "used all 3"
            // headline is truthful; with quota remaining show the proactive line.
            PaywallView(context: left <= 0 ? .quotaExhausted : .proactive(freeExportsLeft: left)) {
                showPaywall = false
            }
            .environment(appState)
            .installTheme(Theme(appState))
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareURLs) { completed in
                // Spend one free export ONLY when the user actually shared/saved a
                // file (completed == true). Cancelling the share costs nothing.
                // Pro is unlimited.
                if completed, !appState.isPro {
                    appState.freeExportsLeft = max(0, appState.freeExportsLeft - 1)
                }
            }
        }
        .fullScreenCover(isPresented: $showPlanEditor) {
            if let room {
                FloorPlanEditorView(room: room)
                    .environment(appState)
                    .installTheme(Theme(appState))
            }
        }
        .onDisappear { exportService.cleanup() }
        .onAppear {
            // Hide the USDZ card when this room has no stored 3D capture.
            if room?.usdzFilename == nil {
                formats.removeAll { $0.format == .usdz }
            }
        }
        // Surface "Export failed" even though this screen is presented as a cover.
        .appAlert(appState)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Export")
                    .font(Theme.sans(26, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(Theme.ink)
                Text(headerSubtitle)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink3)
                // TEMP DIAGNOSTIC — proves this build is running + shows captured insets.
                Text("⚑ insets \(Int(appState.safeAreaInsets.top))/\(Int(appState.safeAreaInsets.bottom))")
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundStyle(.red)
            }
            Spacer()
            Button(action: onClose) {
                Icon("close", size: 18, weight: 2, color: Theme.ink2)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .accessibilityLabel("Close export")
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Quota meter (amber)

    private var quotaMeter: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 11) {
                Icon("download", size: 17, weight: 2, color: Theme.amber)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(left) of \(Self.freeTotal) free exports left")
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    // bars: first `left` segments amber, the rest dim.
                    HStack(spacing: 4) {
                        ForEach(0..<Self.freeTotal, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(i < left ? Theme.amber : Color.white.opacity(0.15))
                                .frame(height: 4)
                        }
                    }
                }
                Text("Go Pro")
                    .font(Theme.sans(12.5, weight: .bold))
                    .foregroundStyle(Theme.amber)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: theme.r(13), style: .continuous)
                    .fill(Theme.amber.withA(0.12)))
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(13), style: .continuous)
                    .strokeBorder(Theme.amber.withA(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(left) of \(Self.freeTotal) free exports left. Go Pro.")
    }

    /// "Room 2 · Scanned Jun 12" — real record metadata, no fictional apartment.
    private var headerSubtitle: String {
        guard let room else { return "Floor plan preview" }
        return "\(room.name) · Scanned \(room.createdAt.formatted(date: .abbreviated, time: .omitted))"
    }

    // MARK: - Floor-plan preview

    private var preview: some View {
        let quantities = plan.quantities
        return ZStack(alignment: .top) {
            FloorPlan(model: plan, accent: theme.accent, unit: theme.unit)
                .padding(.top, 38)
                .padding(.horizontal, 16)
                .padding(.bottom, 30)

            HStack(alignment: .top) {
                Text("FLOOR PLAN · \(theme.unit == .imperial ? "IMPERIAL" : "METRIC")")
                    .font(Theme.mono(10))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                Chip(accent: theme.accent, mono: true, height: 24, fontSize: 10) {
                    Text(UnitFormat.area(quantities.floorAreaSquareMeters, theme.unit))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // Auto-quantities strip (perimeter / wall area / volume) — the
            // renovation math competitors charge for (benchmark parity item) —
            // plus the plan-editor entry (fix any scan inaccuracy in seconds).
            HStack(spacing: 12) {
                quantityChip("PERIM", UnitFormat.lengthFractional(quantities.perimeterMeters, unit: theme.unit))
                quantityChip("WALLS", UnitFormat.area(quantities.wallAreaSquareMeters, theme.unit))
                quantityChip("VOL", UnitFormat.volume(quantities.volumeCubicMeters, theme.unit))
                Spacer(minLength: 0)
                if room != nil {
                    Button { showPlanEditor = true } label: {
                        HStack(spacing: 5) {
                            Icon("ruler2", size: 12, weight: 2, color: theme.accent)
                            Text("Edit Plan")
                                .font(Theme.sans(11.5, weight: .bold))
                                .foregroundStyle(theme.accent)
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(Capsule().fill(theme.accent.withA(0.15)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit floor plan")
                }
            }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 10)
        }
        .frame(height: 212)
        .background(
            RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "#15171c"), Color(hex: "#101216")],
                    startPoint: .top, endPoint: .bottom)))
        .overlay(
            RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func quantityChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(Theme.mono(8.5))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
            Text(value)
                .font(Theme.mono(10.5, weight: .bold))
                .foregroundStyle(Theme.ink2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.07)))
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: - Format grid

    private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var formatGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FORMATS")
                .font(Theme.sans(12, weight: .regular))
                .tracking(0.4)
                .foregroundStyle(Theme.ink3)

            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(formats.indices, id: \.self) { i in
                    formatCard(i)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatCard(_ i: Int) -> some View {
        let f = formats[i]
        return Button {
            formats[i].on.toggle()
        } label: {
            HStack(spacing: 11) {
                Icon(f.format.icon, size: 19, weight: 1.8, color: f.on ? theme.accent : Theme.ink2)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: theme.r(10), style: .continuous)
                            .fill(f.on ? theme.accent.withA(0.25) : Color.white.opacity(0.06)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(f.format.displayName)
                        .font(Theme.sans(14.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(f.format.detail)
                        .font(Theme.sans(11.5))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer(minLength: 0)
                if f.on {
                    Icon("check", size: 17, weight: 2.4, color: theme.accent)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.r(14), style: .continuous)
                    .fill(f.on ? theme.accent.withA(0.14) : Color.white.opacity(0.04)))
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(14), style: .continuous)
                    .strokeBorder(f.on ? theme.accent.withA(0.6) : Color.white.opacity(0.08),
                                  lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(f.format.displayName), \(f.format.detail)")
        .accessibilityValue(f.on ? "included" : "not included")
        .accessibilityAddTraits(f.on ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Include toggles

    private var includeToggles: some View {
        VStack(spacing: 0) {
            includeRow("Dimensions", isOn: $includeDimensions, first: true)
            includeRow("Furniture & openings", isOn: $includeFurniture, first: false)
            includeRow("Grid & scale bar", isOn: $includeGrid, first: false)
        }
    }

    private func includeRow(_ label: String, isOn: Binding<Bool>, first: Bool) -> some View {
        HStack {
            Text(label)
                .font(Theme.sans(14.5))
                .foregroundStyle(Theme.ink)
            Spacer()
            IOSToggle(isOn: isOn)
                .accessibilityLabel(label)
        }
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .overlay(alignment: .top) {
            if !first {
                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
            }
        }
    }

    // MARK: - CTA bar

    private var ctaBar: some View {
        Button(action: exportTapped) {
            HStack(spacing: 9) {
                if isExporting {
                    ProgressView().tint(.white)
                } else {
                    Icon(locked ? "cube3d" : "share", size: 19, weight: 2.2, color: .white)
                }
                Text(locked ? "Upgrade to export" : "Export \(enabledCount) \(enabledCount == 1 ? "file" : "files")")
                    .font(Theme.sans(16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: theme.r(16), style: .continuous)
                    .fill(theme.accent.withA(locked ? 0.35 : 0.96)))
            .shadow(color: locked ? .clear : theme.accent.withA(0.4), radius: 13, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isExporting || (!locked && enabledCount == 0))
        .opacity(!locked && enabledCount == 0 ? 0.5 : 1)
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 14) // home-indicator clearance now comes from the window bottom inset
        .accessibilityLabel(locked ? "Upgrade to export" : "Export \(enabledCount) files")
    }

    // MARK: - Actions

    /// Generates every selected format, hands the files to the share sheet,
    /// and spends one free export ONLY after successful generation.
    private func exportTapped() {
        // Locked (no quota left, not Pro): straight to the paywall.
        guard !locked else {
            showPaywall = true
            return
        }
        guard !isExporting, enabledCount > 0 else { return }
        isExporting = true

        let selected = formats.filter(\.on).map(\.format)
        let exportPlan = plan
        let name = room?.name ?? "Floor Plan"
        let usdzFilename = room?.usdzFilename
        let unit = theme.unit

        // Generate off the synchronous button path. Each format must render on the
        // main actor (PDF/PNG use ImageRenderer/UIGraphics), but yielding between
        // formats keeps the runloop live so the spinner animates and the app never
        // freezes for the whole batch (was a hard freeze → force-quit).
        Task { @MainActor in
            var urls: [URL] = []
            do {
                for format in selected {
                    await Task.yield()
                    urls.append(try exportService.export(plan: exportPlan,
                                                         name: name,
                                                         usdzFilename: usdzFilename,
                                                         format: format,
                                                         unit: unit))
                }
            } catch {
                isExporting = false
                appState.presentAlert(title: "Export failed",
                                      message: error.localizedDescription)
                return
            }
            isExporting = false
            shareURLs = urls
            showShareSheet = true
            // NOTE: the free-export quota is spent on share COMPLETION, not here —
            // generating then cancelling the share must not cost a free export.
            // See the ShareSheet onComplete handler.
        }
    }
}

/// UIActivityViewController bridge for sharing the generated files.
/// `onComplete(true)` fires only when the user actually shared/saved (not cancel),
/// so the caller can spend the free-export quota fairly.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]
    var onComplete: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
