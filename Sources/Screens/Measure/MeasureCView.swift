// MeasureCView.swift — Direction C · PRO CONSOLE.
//
// Tool-rail + full control-deck variant, defaulting to AREA mode. Ported 1:1
// from the HTML reference `MeasureC`:
//   • closed 4-node polygon with accent area fill, 4 segment ValuePills, and a
//     big centered floor-area readout
//   • top-right LiDAR/fallback status, left vertical tool rail (pin/distance/
//     area/volume/angle)
//   • bottom pro console: horizontally-scrolling PERIMETER chips, compact
//     ModeSwitch + check Shutter, secondary tool row (Undo/Layers/Snap) + M/FT
//     unit indicator
//
// LiDAR ⇄ fallback: amber "VISUAL" chip + FallbackBanner + dimmer grid + mesh
// off when `theme.lidar` is false.

import SwiftUI

public struct MeasureCView: View {
    @Environment(\.theme) private var theme

    private let service: ARMeasureService
    @State private var mode: MeasureMode = .area
    /// Active tool-rail item (source default: area).
    @State private var tool: String = "area"

    private let railTools = ["pin", "distance", "area", "volume", "angle"]

    public init(service: ARMeasureService = SimulatedARMeasureService()) {
        self.service = service
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            CameraBackdrop(accent: theme.accent,
                           mesh: theme.lidar,
                           gridAlpha: theme.lidar ? 0.22 : 0.12)
            FeaturePoints(accent: theme.accent)

            scene

            topRightStatus
            toolRail
            console
        }
        .background(Theme.cameraBG.ignoresSafeArea())
        .onAppear { service.start() }
        .onDisappear { service.stop() }
    }

    // MARK: - AR geometry (closed area polygon)

    private var scene: some View {
        MeasureScene(
            accent: theme.accent,
            pts: [ScenePoint(x: 92, y: 520),
                  ScenePoint(x: 318, y: 556),
                  ScenePoint(x: 286, y: 712),
                  ScenePoint(x: 60, y: 668)],
            segs: [
                SceneSegment(x: 205, y: 524, text: UnitFormat.length(2.34, theme.unit)),
                SceneSegment(x: 302, y: 634, text: UnitFormat.length(1.80, theme.unit)),
                SceneSegment(x: 173, y: 706, text: UnitFormat.length(2.34, theme.unit)),
                SceneSegment(x: 76, y: 600, text: UnitFormat.length(1.80, theme.unit)),
            ],
            area: SceneArea(x: 189, y: 614,
                            text: areaValue, sub: areaSub))
        .ignoresSafeArea()
    }

    /// Floor area value split into number + unit, like the source's
    /// `fmtArea(...).split(' ')`.
    private var areaValue: String {
        UnitFormat.area(4.21, theme.unit).components(separatedBy: " ").first ?? ""
    }
    private var areaSub: String {
        let unit = UnitFormat.area(4.21, theme.unit).components(separatedBy: " ").dropFirst().first ?? ""
        return unit.uppercased() + " · FLOOR"
    }

    // MARK: - Top-right status

    private var topRightStatus: some View {
        VStack(alignment: .trailing, spacing: 8) {
            LidarStatusChip(shortLabel: true)
            if !theme.lidar { FallbackBanner() }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 14)
        .padding(.top, 8)
    }

    // MARK: - Left tool rail

    private var toolRail: some View {
        VStack(spacing: 4) {
            ForEach(railTools, id: \.self) { ic in
                railButton(ic)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                .fill(Color(.sRGB, red: 10/255, green: 12/255, blue: 15/255, opacity: 0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.leading, 12)
        .padding(.top, 120)
    }

    @ViewBuilder
    private func railButton(_ ic: String) -> some View {
        let on = ic == tool
        Icon(ic, size: 20, weight: 1.8, color: on ? .white : Theme.ink3)
            .frame(width: 42, height: 42)
            .background(
                RoundedRectangle(cornerRadius: theme.r(13), style: .continuous)
                    .fill(on ? theme.accent.withA(0.92) : .clear)
            )
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { tool = ic } }
            .accessibilityLabel("\(ic) tool")
            .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: - Bottom pro console

    private var console: some View {
        VStack(spacing: 0) {
            perimeterStrip
                .padding(.bottom, 12)

            HStack(spacing: 12) {
                ModeSwitch(accent: theme.accent, active: $mode, compact: true)
                Shutter(accent: theme.accent, size: 62, icon: "check") { service.finish() }
                    .accessibilityLabel("Finish measurement")
            }
            .padding(.horizontal, 14)

            secondaryRow
                .padding(.horizontal, 16)
                .padding(.top, 12)
        }
        .padding(.top, 14)
        // Lift the console above the floating tab bar (~58pt over the safe area)
        // so the secondary tool row + unit indicator aren't occluded. The camera
        // backdrop stays full-bleed; only the controls clear the bar.
        .padding(.bottom, 72)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color(.sRGB, red: 10/255, green: 11/255, blue: 14/255, opacity: 0.92), location: 0.34),
                    .init(color: Color(.sRGB, red: 10/255, green: 11/255, blue: 14/255, opacity: 0.92), location: 1),
                ],
                startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .bottom)
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var perimeterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("PERIMETER")
                    .font(Theme.mono(10))
                    .tracking(1)
                    .foregroundStyle(Theme.ink3)
                ForEach(Array(runlist.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 7) {
                        Text(item.label)
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.ink2)
                        Text(item.value)
                            .font(Theme.mono(12, weight: .bold))
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: theme.r(10), style: .continuous)
                            .fill(Color.white.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.r(10), style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private var runlist: [(label: String, value: String)] {
        [("Wall A", UnitFormat.length(2.34, theme.unit)),
         ("Wall B", UnitFormat.length(1.80, theme.unit)),
         ("Wall C", UnitFormat.length(2.34, theme.unit)),
         ("Wall D", UnitFormat.length(1.80, theme.unit))]
    }

    private var secondaryRow: some View {
        HStack {
            HStack(spacing: 22) {
                secondaryTool("undo", "Undo") { service.undo() }
                secondaryTool("layers", "Layers") {}
                secondaryTool("grid", "Snap") {}
            }
            Spacer()
            unitIndicator
        }
    }

    @ViewBuilder
    private func secondaryTool(_ ic: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Icon(ic, size: 19, weight: 1.8, color: Theme.ink2)
                Text(label)
                    .font(Theme.sans(9.5))
                    .foregroundStyle(Theme.ink3)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Read-only M / FT indicator reflecting the live unit (driven by Settings).
    private var unitIndicator: some View {
        HStack(spacing: 8) {
            Text("M")
                .foregroundStyle(theme.unit == .metric ? Color.white : Theme.ink3)
            Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 12)
            Text("FT")
                .foregroundStyle(theme.unit == .imperial ? Color.white : Theme.ink3)
        }
        .font(Theme.mono(12, weight: .bold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .accessibilityLabel("Unit: \(theme.unit == .metric ? "metric" : "imperial")")
    }
}

#Preview {
    MeasureCView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
