// MeasureAView.swift — Direction A · PRECISION HUD.
//
// Dense, instrument-like, mono-everywhere live AR capture. Ported 1:1 from
// measure.jsx / the HTML reference `MeasureA`:
//   • top HUD: active-mode chip + LiDAR/fallback status chip
//   • technical telemetry strip (TRACK bars · ±precision · DEPTH/EST · ● REC)
//   • multi-point geometry (3 nodes) with segment ValuePills + an angle arc
//   • big mono live readout (label + value + total/points)
//   • bottom deck: ModeSwitch + undo / shutter / check
//
// LiDAR ⇄ fallback: when `theme.lidar` is false → mesh off, gridAlpha 0.12,
// amber "LiDAR UNAVAILABLE · VISUAL" chip, "± 2 cm", "EST 1.8 m", amber TRACK
// bars (fewer lit), triangulate reticle guidance, and the FallbackBanner.

import SwiftUI

public struct MeasureAView: View {
    @Environment(\.theme) private var theme

    /// AR backend seam (simulated in-sim). Injected; defaults to the simulator.
    private let service: ARMeasureService
    @State private var mode: MeasureMode = .distance
    /// Live point count mirrored from the service so the capture controls
    /// visibly respond. Seeded to the design's canonical resting count (3 nodes);
    /// `.onAppear` reconciles it with the injected service's actual count.
    @State private var pointCount: Int = 3

    public init(service: ARMeasureService = SimulatedARMeasureService()) {
        self.service = service
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Camera + AR — mesh/grid density follow LiDAR availability.
            CameraBackdrop(accent: theme.accent,
                           mesh: theme.lidar,
                           gridAlpha: theme.lidar ? 0.22 : 0.12)
            FeaturePoints(accent: theme.accent)

            scene
            ReticleLayer(accent: theme.accent, label: theme.reticleGuidance)

            topHUD
            bigReadout
            bottomDeck
        }
        .background(Theme.cameraBG.ignoresSafeArea())
        .onAppear { service.start(); pointCount = service.placedCount }
        .onDisappear { service.stop() }
    }

    // MARK: - AR geometry

    private var scene: some View {
        MeasureScene(
            accent: theme.accent,
            pts: [ScenePoint(x: 70, y: 560),
                  ScenePoint(x: 300, y: 600),
                  ScenePoint(x: 214, y: 752)],
            segs: [
                SceneSegment(x: 196, y: 558,
                             text: UnitFormat.length(2.34, theme.unit), active: true),
                SceneSegment(x: 268, y: 690,
                             text: UnitFormat.length(1.62, theme.unit)),
            ],
            angle: SceneAngle(
                center: ScenePoint(x: 306.59, y: 603.21), radius: 28,
                startAngle: .degrees(-103.6), endAngle: .degrees(161.71),
                x: 312, y: 600, text: UnitFormat.angle(118.4)),
            activeTo: ScenePoint(x: 201, y: 470))
        .ignoresSafeArea()
    }

    // MARK: - Top HUD (chips + telemetry strip)

    private var topHUD: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Chip(accent: theme.accent, active: true, mono: true) {
                    Icon(mode.icon, size: 14, weight: 2, color: .white)
                    Text(mode.chipLabel)
                }
                Spacer()
                LidarStatusChip()
            }

            if !theme.lidar { FallbackBanner() }

            telemetryStrip
        }
        .padding(.horizontal, 14)
        .padding(.top, 44) // clears the floating HUD-style picker in MeasureView
    }

    private var telemetryStrip: some View {
        HStack(spacing: 14) {
            // TRACK quality bars — accent (LiDAR) / amber (fallback), fewer lit on fallback.
            HStack(spacing: 5) {
                Text("TRACK").foregroundStyle(Theme.ink3)
                HStack(spacing: 2) {
                    ForEach(Array(trackBars.enumerated()), id: \.offset) { _, opacity in
                        RoundedRectangle(cornerRadius: 1)
                            .fill((theme.lidar ? theme.accent : Theme.amber).opacity(opacity))
                            .frame(width: 3, height: 9)
                    }
                }
            }
            // ± precision
            HStack(spacing: 4) {
                Text("±").foregroundStyle(Theme.ink3)
                Text(theme.precision)
            }
            // DEPTH (LiDAR) / EST (fallback)
            HStack(spacing: 4) {
                Text(theme.lidar ? "DEPTH" : "EST").foregroundStyle(Theme.ink3)
                Text(theme.lidar ? "1.82 m" : "1.8 m")
            }
            Spacer(minLength: 0)
            Text("● REC").foregroundStyle(theme.accent)
        }
        .font(Theme.mono(10.5))
        .tracking(0.3)
        .foregroundStyle(Theme.ink2)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: theme.r(10), style: .continuous)
                .fill(Theme.glass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.r(10), style: .continuous)
                .strokeBorder(Theme.glassBorder, lineWidth: 1)
        )
    }

    /// TRACK bar opacities: 3-of-4 lit (LiDAR) vs 2-of-4 lit (fallback).
    private var trackBars: [Double] {
        theme.lidar ? [1, 1, 1, 0.3] : [1, 1, 0.3, 0.3]
    }

    // MARK: - Big live readout

    private var bigReadout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(mode.readoutLabel)
                .font(Theme.mono(11))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            Text(readoutValue)
                .font(Theme.mono(46, weight: .bold))
                .tracking(-1)
                .foregroundStyle(Theme.ink)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                .padding(.top, 2)
            // Live point count: seeded to the canonical 3 PTS, then place/undo
            // visibly bump it. TOTAL stays on the verified design value.
            Text("TOTAL \(theme.unit == .imperial ? "12′ 11″" : "3.96 m") · \(pointCount) PTS")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.ink2)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 16)
        .padding(.bottom, 188)
    }

    /// Big-readout value adapts to the active mode (source defaults).
    private var readoutValue: String {
        switch mode {
        case .distance: return UnitFormat.length(2.34, theme.unit)
        case .area:     return UnitFormat.area(4.21, theme.unit)
        case .volume:   return UnitFormat.volume(1.86, theme.unit)
        case .angle:    return UnitFormat.angle(118.4)
        }
    }

    // MARK: - Bottom control deck

    private var bottomDeck: some View {
        VStack(spacing: 12) {
            ModeSwitch(accent: theme.accent, active: $mode)
            HStack {
                MeasureCircleBtn(icon: "undo") {
                    service.undo(); pointCount = service.placedCount
                }
                .accessibilityLabel("Undo last point")
                Spacer()
                Shutter(accent: theme.accent, icon: "plus") {
                    service.placePoint(); pointCount = service.placedCount
                }
                .accessibilityLabel("Add measurement point")
                Spacer()
                MeasureCircleBtn(icon: "check") {
                    service.finish(); pointCount = service.placedCount
                }
                .accessibilityLabel("Finish measurement")
            }
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 40)
    }
}

#Preview {
    MeasureAView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
