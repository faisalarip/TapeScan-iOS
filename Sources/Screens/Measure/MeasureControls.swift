// MeasureControls.swift — Measure-screen control atoms ported from measure.jsx.
//
// `ModeSwitch` (the segmented Distance/Area/Volume/Angle deck) and
// `MeasureCircleBtn` (the glass undo/check circle) live LOCAL to the design's
// measure.jsx, so they are reproduced here rather than in shared Components.
// The capture `Shutter` + value `ValuePill` + glass `Chip` come from
// Sources/Components and are reused verbatim.

import SwiftUI
import SwiftData
import UIKit

// MARK: - Shared finish / autosave (production parity across Precision/Minimal/Pro)

/// Persistence shared by all three Measure HUD directions so they behave
/// identically: finishing saves a `MeasurementRecord` to History and clears the
/// crash-recovery draft; every change autosaves the draft; placing a point
/// surfaces the standard guidance alert on a miss.
@MainActor
enum MeasureSession {
    /// Finalize the current measurement: persist to History (SwiftData) + clear
    /// the autosave draft. No-op if nothing was measured.
    static func finish(_ service: any ARMeasureService,
                       context: ModelContext,
                       appState: AppState) {
        let points = service.points
        guard let result = service.finish() else { return }
        SessionDraftStore.clear()
        do {
            let count = (try? context.fetchCount(FetchDescriptor<MeasurementRecord>())) ?? 0
            let record = try MeasurementRecord(name: "Measurement \(count + 1)",
                                               mode: result.mode,
                                               points: points,
                                               result: result)
            context.insert(record)
            try context.save()
            // Confirm the save: a visible toast + a success haptic (the screen also
            // clears and a new History row appears) — finishing is never silent.
            appState.presentNotice("Measurement saved")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            appState.presentAlert(title: "Couldn't save measurement",
                                  message: error.localizedDescription)
        }
    }

    /// Crash-recovery autosave after any change (clears when empty).
    static func autosave(_ service: any ARMeasureService) {
        if service.points.isEmpty {
            SessionDraftStore.clear()
        } else {
            SessionDraftStore.save(MeasureSessionDraft(
                mode: service.mode, points: service.points, savedAt: Date()))
        }
    }

    /// Drop a point at the reticle; on a miss surface the standard guidance alert.
    /// Always autosaves. Returns whether a point was placed.
    @discardableResult
    static func place(_ service: any ARMeasureService, appState: AppState) -> Bool {
        let placed = service.placePoint() != nil
        if placed {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            appState.presentAlert(title: "No surface found",
                                  message: "Aim the reticle at a flat surface and try again.")
        }
        autosave(service)
        return placed
    }
}

/// Bottom mode switcher: a glass segmented control of measurement modes.
/// `compact` drops the text label (icon-only) — used by Direction C's console.
struct ModeSwitch: View {
    @Environment(\.theme) private var theme
    let accent: Color
    @Binding var active: MeasureMode
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MeasureMode.allCases) { mode in
                segment(mode)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: theme.r(14), style: .continuous)
                .fill(Color(.sRGB, red: 10/255, green: 12/255, blue: 15/255, opacity: 0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.r(14), style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segment(_ mode: MeasureMode) -> some View {
        let on = mode == active
        VStack(spacing: 3) {
            Icon(mode.icon, size: 18, weight: 1.8,
                 color: on ? .white : Theme.ink3)
            if !compact {
                Text(mode.label)
                    .font(Theme.sans(10, weight: .semibold))
                    .tracking(0.2)
                    .foregroundStyle(on ? Color.white : Theme.ink3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 6 : 8)
        .background(
            RoundedRectangle(cornerRadius: theme.r(11), style: .continuous)
                .fill(on ? accent.withA(0.92) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) { active = mode }
        }
        .accessibilityLabel(mode.label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A glass circle button local to the measure deck (undo / check secondary
/// actions). Distinct from the shared `CircleButton` only in default fill tones
/// to match measure.jsx's `CircleBtn`.
struct MeasureCircleBtn: View {
    let icon: String
    var size: CGFloat = 44
    var solid: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Icon(icon, size: size * 0.42, weight: 1.9, color: .white)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(solid
                        ? Color.white.opacity(0.12)
                        : Color(.sRGB, red: 10/255, green: 12/255, blue: 15/255, opacity: 0.55))
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
    }
}

/// The LiDAR / fallback status chip used across the three directions.
/// LiDAR → green "LiDAR · ACTIVE"; fallback → amber "… · VISUAL".
/// `shortLabel` toggles the abbreviated forms used by Direction C ("LiDAR" /
/// "VISUAL").
struct LidarStatusChip: View {
    @Environment(\.theme) private var theme
    var shortLabel: Bool = false

    var body: some View {
        if theme.lidar {
            Chip(accent: theme.accent, mono: true) {
                StatusDot(color: Theme.successGreen, blink: true)
                Text(shortLabel ? "LiDAR" : "LiDAR · ACTIVE")
            }
        } else {
            Chip(accent: Theme.amber, active: true, mono: true) {
                StatusDot(color: .white, blink: true)
                Text(shortLabel ? "VISUAL" : "LiDAR UNAVAILABLE · VISUAL")
            }
        }
    }
}

/// The mono caption shown under the reticle — adapts to tracking mode.
extension Theme {
    /// Reticle guidance copy: align/tap (LiDAR) vs triangulate (fallback).
    var reticleGuidance: String {
        lidar ? "ALIGN · TAP TO SET POINT" : "MOVE SIDE-TO-SIDE TO TRIANGULATE"
    }
}

/// User-facing reticle/HUD guidance for the current AR tracking state, so degraded
/// tracking is never silent (accuracy guardrail — the service computes these
/// coaching strings but the HUD must show them).
extension TrackingQuality {
    /// Returns `defaultLabel` when tracking is normal; a short coaching string otherwise.
    func guidance(default defaultLabel: String) -> String {
        switch self {
        case .normal:           return defaultLabel
        case .limited(let why): return why
        case .initializing:     return "Starting AR — move slowly to map the area"
        case .notAvailable:     return "Tracking lost — aim at a lit, textured surface"
        }
    }
}

/// Positions the center targeting `Reticle` at the source's 47% vertical anchor
/// (matching measure.jsx `top: 47%`) regardless of safe-area chrome.
struct ReticleLayer: View {
    let accent: Color
    let label: String

    var body: some View {
        GeometryReader { geo in
            Reticle(accent: accent, label: label)
                .position(x: geo.size.width / 2,
                          y: geo.size.height * SceneMapping.reticleAnchorY)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
