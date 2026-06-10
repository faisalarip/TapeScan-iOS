// MeasureBView.swift — Direction B · MINIMAL FOCUS.
//
// Calm, one-big-readout, generous-space variant. Ported 1:1 from the HTML
// reference `MeasureB`:
//   • warm camera backdrop, single 2-point segment with one ValuePill
//   • centered top status pill (Distance · LiDAR  /  Distance · VISUAL fallback)
//   • bottom rounded glass card: big sans readout (label + value + segment meta),
//     text-tab mode switch (underline indicator), undo / shutter / check
//
// LiDAR ⇄ fallback: amber pill + "VISUAL" + FallbackBanner + triangulate
// reticle guidance when `theme.lidar` is false.

import SwiftUI

public struct MeasureBView: View {
    @Environment(\.theme) private var theme

    private let service: ARMeasureService
    @State private var mode: MeasureMode = .distance

    public init(service: ARMeasureService = SimulatedARMeasureService()) {
        self.service = service
    }

    public var body: some View {
        ZStack(alignment: .top) {
            CameraBackdrop(accent: theme.accent,
                           warmth: 0.4,
                           mesh: theme.lidar,
                           gridAlpha: theme.lidar ? 0.22 : 0.12)

            scene
            ReticleLayer(accent: theme.accent,
                         label: theme.lidar ? "Tap to drop point"
                                            : "MOVE SIDE-TO-SIDE TO TRIANGULATE")

            topPill
            bottomCard
        }
        .background(Theme.cameraBG.ignoresSafeArea())
        .onAppear { service.start() }
        .onDisappear { service.stop() }
    }

    // MARK: - AR geometry (single segment)

    private var scene: some View {
        MeasureScene(
            accent: theme.accent,
            pts: [ScenePoint(x: 96, y: 600), ScenePoint(x: 308, y: 656)],
            segs: [SceneSegment(x: 202, y: 612,
                                text: UnitFormat.length(2.18, theme.unit), active: true)],
            activeTo: ScenePoint(x: 201, y: 472))
        .ignoresSafeArea()
    }

    // MARK: - Centered top status pill

    private var topPill: some View {
        VStack(spacing: 8) {
            if theme.lidar {
                Chip(accent: theme.accent, height: 36, fontSize: 13) {
                    Icon("distance", size: 15, weight: 2, color: .white)
                    Text("Distance")
                    pillDivider(opacity: 0.2)
                    StatusDot(color: Theme.successGreen)
                    Text("LiDAR")
                }
            } else {
                Chip(accent: Theme.amber, active: true, height: 36, fontSize: 13) {
                    Icon("distance", size: 15, weight: 2, color: .white)
                    Text("Distance")
                    pillDivider(opacity: 0.25)
                    StatusDot(color: .white)
                    Text("VISUAL")
                }
            }
            if !theme.lidar { FallbackBanner() }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 52) // clears the floating HUD-style picker in MeasureView
    }

    private func pillDivider(opacity: Double) -> some View {
        Rectangle()
            .fill(Color.white.opacity(opacity))
            .frame(width: 1, height: 14)
            .padding(.horizontal, 2)
    }

    // MARK: - Bottom glass card

    private var bottomCard: some View {
        VStack(spacing: 0) {
            // value row
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(valueLabel)
                        .font(Theme.sans(12))
                        .tracking(0.3)
                        .foregroundStyle(Theme.ink3)
                        .padding(.bottom, 2)
                    Text(value)
                        .font(Theme.sans(44, weight: .semibold))
                        .tracking(-1.5)
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("1 segment")
                        .foregroundStyle(Theme.ink2)
                    Text(theme.unit == .imperial ? "feet · in" : "meters")
                        .foregroundStyle(Theme.ink3)
                }
                .font(Theme.sans(12))
                .lineSpacing(4)
            }
            .padding(.bottom, 18)

            // text tabs
            HStack(spacing: 18) {
                ForEach(MeasureMode.allCases) { m in
                    textTab(m)
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 18)

            // controls
            HStack {
                MeasureCircleBtn(icon: "undo", size: 48, solid: true) { service.undo() }
                    .accessibilityLabel("Undo last point")
                Spacer()
                Shutter(accent: theme.accent, size: 76, icon: "plus") { _ = service.placePoint() }
                    .accessibilityLabel("Add measurement point")
                Spacer()
                MeasureCircleBtn(icon: "check", size: 48, solid: true) { service.finish() }
                    .accessibilityLabel("Finish measurement")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: theme.r(30), style: .continuous)
                .fill(Color(.sRGB, red: 16/255, green: 18/255, blue: 22/255, opacity: 0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.r(30), style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 25, y: 16)
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 40)
    }

    @ViewBuilder
    private func textTab(_ m: MeasureMode) -> some View {
        let on = m == mode
        VStack(spacing: 6) {
            Text(m.label)
                .font(Theme.sans(13, weight: .semibold))
                .foregroundStyle(on ? Color.white : Theme.ink3)
            Rectangle()
                .fill(on ? theme.accent : .clear)
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .fixedSize()
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { mode = m } }
        .accessibilityLabel(m.label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: - Mode-driven readout

    private var valueLabel: String {
        switch mode {
        case .distance: return "Length"
        case .area:     return "Area"
        case .volume:   return "Volume"
        case .angle:    return "Angle"
        }
    }

    private var value: String {
        switch mode {
        case .distance: return UnitFormat.length(2.18, theme.unit)
        case .area:     return UnitFormat.area(4.21, theme.unit)
        case .volume:   return UnitFormat.volume(1.86, theme.unit)
        case .angle:    return UnitFormat.angle(118.4)
        }
    }
}

#Preview {
    MeasureBView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
