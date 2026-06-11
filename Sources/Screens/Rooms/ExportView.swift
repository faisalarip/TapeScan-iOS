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

    /// A selectable export format card.
    private struct Format: Identifiable {
        let id: String        // "glTF"
        let detail: String    // "3D model"
        let icon: String      // icon name
        var on: Bool
    }

    @State private var formats: [Format] = [
        Format(id: "glTF", detail: "3D model", icon: "cube3d", on: true),
        Format(id: "SVG", detail: "Vector plan", icon: "ruler2", on: true),
        Format(id: "PNG", detail: "Image", icon: "grid", on: false),
        Format(id: "PDF", detail: "Document", icon: "download", on: false),
    ]

    @State private var includeDimensions = true
    @State private var includeFurniture = true
    @State private var includeGrid = false

    @State private var showPaywall = false

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
        ZStack {
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
            // renovation math competitors charge for (benchmark parity item).
            HStack(spacing: 12) {
                quantityChip("PERIM", UnitFormat.lengthFractional(quantities.perimeterMeters, unit: theme.unit))
                quantityChip("WALLS", UnitFormat.area(quantities.wallAreaSquareMeters, theme.unit))
                quantityChip("VOL", UnitFormat.volume(quantities.volumeCubicMeters, theme.unit))
                Spacer(minLength: 0)
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
                Icon(f.icon, size: 19, weight: 1.8, color: f.on ? theme.accent : Theme.ink2)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: theme.r(10), style: .continuous)
                            .fill(f.on ? theme.accent.withA(0.25) : Color.white.opacity(0.06)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(f.id)
                        .font(Theme.sans(14.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(f.detail)
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
        .accessibilityLabel("\(f.id), \(f.detail)")
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
                Icon(locked ? "cube3d" : "share", size: 19, weight: 2.2, color: .white)
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
        .disabled(!locked && enabledCount == 0)
        .opacity(!locked && enabledCount == 0 ? 0.5 : 1)
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 40)
        .accessibilityLabel(locked ? "Upgrade to export" : "Export \(enabledCount) files")
    }

    // MARK: - Actions

    private func exportTapped() {
        // Locked (no quota left, not Pro): straight to the paywall.
        guard !locked else {
            showPaywall = true
            return
        }
        // Pro users export without touching the free quota.
        guard !appState.isPro else { return }
        // Spend one free export.
        appState.freeExportsLeft = max(0, appState.freeExportsLeft - 1)
        // If that was the last one, surface the paywall.
        if appState.freeExportsLeft <= 0 {
            showPaywall = true
        }
    }
}

#Preview {
    ExportView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
