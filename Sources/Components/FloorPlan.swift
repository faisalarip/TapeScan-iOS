// FloorPlan.swift — L-shaped schematic floor plan with dimension labels.
// Ported from support.jsx `FloorPlan` on the 320×300 source viewBox.

import SwiftUI

public struct FloorPlan: View {
    private let accent: Color
    private let unit: MeasureUnit
    private let showDims: Bool
    private let small: Bool

    /// - Parameters:
    ///   - accent: outline / fill / dim-label tint. Defaults to live theme accent.
    ///   - unit: drives the dimension labels (metric vs imperial).
    ///   - showDims: draw the dimension tick lines + labels. Default true.
    ///   - small: compact variant (thinner walls, no room labels/dims). Default false.
    public init(accent: Color? = nil,
                unit: MeasureUnit = .metric,
                showDims: Bool = true,
                small: Bool = false) {
        self.accent = accent ?? Theme.fallback.accent
        self.unit = unit
        self.showDims = showDims
        self.small = small
    }

    // Source viewBox is 320×300.
    private static let vbW: CGFloat = 320
    private static let vbH: CGFloat = 300

    /// Maps source viewBox coordinates into a fitted, centered rect.
    private struct Mapping {
        let scale: CGFloat
        let ox: CGFloat
        let oy: CGFloat
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * scale, y: oy + y * scale)
        }
        init(_ size: CGSize) {
            scale = min(size.width / FloorPlan.vbW, size.height / FloorPlan.vbH)
            ox = (size.width - FloorPlan.vbW * scale) / 2
            oy = (size.height - FloorPlan.vbH * scale) / 2
        }
    }

    public var body: some View {
        GeometryReader { geo in
            content(Mapping(geo.size))
        }
    }

    @ViewBuilder
    private func content(_ m: Mapping) -> some View {
        let s = m.scale
        let wall: CGFloat = (small ? 3 : 4) * s
        ZStack {
            // L-shape outline fill + stroke: M30 40 H230 V120 H290 V260 H30 Z
            outline(m).fill(accent.withA(0.07))
            outline(m).stroke(accent, style: StrokeStyle(lineWidth: wall, lineJoin: .round))

            // interior partitions
            partitions(m).stroke(Color.white.opacity(0.32), lineWidth: 2 * s)

            // door gaps (cut with surface color)
            doorGaps(m).stroke(Color(hex: "#15171c"), lineWidth: 4 * s)

            // door swing arc
            doorSwing(m).stroke(Color.white.opacity(0.3), lineWidth: 1.2 * s)

            if !small {
                roomLabels(m)
            }
            if showDims && !small {
                dimensions(m)
            }
        }
    }

    // MARK: - Geometry

    private func outline(_ m: Mapping) -> Path {
        var p = Path()
        p.move(to: m.point(30, 40))
        p.addLine(to: m.point(230, 40))
        p.addLine(to: m.point(230, 120))
        p.addLine(to: m.point(290, 120))
        p.addLine(to: m.point(290, 260))
        p.addLine(to: m.point(30, 260))
        p.closeSubpath()
        return p
    }

    private func partitions(_ m: Mapping) -> Path {
        var p = Path()
        p.move(to: m.point(150, 40));  p.addLine(to: m.point(150, 180))
        p.move(to: m.point(30, 180));  p.addLine(to: m.point(290, 180))
        p.move(to: m.point(150, 120)); p.addLine(to: m.point(290, 120))
        return p
    }

    private func doorGaps(_ m: Mapping) -> Path {
        var p = Path()
        p.move(to: m.point(150, 92)); p.addLine(to: m.point(150, 118))
        p.move(to: m.point(92, 180)); p.addLine(to: m.point(120, 180))
        return p
    }

    private func doorSwing(_ m: Mapping) -> Path {
        // M150 118 A26 26 0 0 1 176 92  (quarter arc, radius 26)
        var p = Path()
        p.move(to: m.point(150, 118))
        p.addArc(center: m.point(176, 118), radius: 26 * m.scale,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        return p
    }

    private func roomLabels(_ m: Mapping) -> some View {
        let labels: [(String, CGFloat, CGFloat)] = [
            ("LIVING", 90, 74), ("BED", 220, 78),
            ("KITCHEN", 90, 222), ("BATH", 225, 222),
        ]
        return ForEach(labels, id: \.0) { lbl in
            Text(lbl.0)
                .font(Theme.mono(11 * m.scale))
                .foregroundStyle(Color.white.opacity(0.55))
                .position(m.point(lbl.1, lbl.2))
        }
    }

    private func dimensions(_ m: Mapping) -> some View {
        let s = m.scale
        let top = lengthLabel(5.20)
        let left = lengthLabel(5.70)
        return ZStack {
            // top dimension line + ticks
            Path { p in
                p.move(to: m.point(30, 24)); p.addLine(to: m.point(230, 24))
                p.move(to: m.point(30, 20)); p.addLine(to: m.point(30, 28))
                p.move(to: m.point(230, 20)); p.addLine(to: m.point(230, 28))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 1)
            Text(top)
                .font(Theme.mono(10.5 * s))
                .foregroundStyle(accent)
                .position(m.point(130, 14))

            // left dimension line + rotated label
            Path { p in
                p.move(to: m.point(16, 40)); p.addLine(to: m.point(16, 260))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 1)
            Text(left)
                .font(Theme.mono(10.5 * s))
                .foregroundStyle(accent)
                .rotationEffect(.degrees(-90))
                .position(m.point(12, 150))
        }
    }

    /// Dimension label respecting the unit system (matches source `lbl`).
    private func lengthLabel(_ meters: Double) -> String {
        unit == .imperial
            ? UnitFormat.length(meters, .imperial)
            : String(format: "%.2fm", meters)
    }
}

#Preview {
    ZStack {
        Color(hex: "#101216")
        FloorPlan(accent: AccentOption.blue.color, unit: .metric)
            .padding(24)
    }
    .frame(width: 360, height: 340)
}
