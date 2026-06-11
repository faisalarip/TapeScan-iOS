// FloorPlan.swift — model-driven schematic floor plan with dimension labels.
//
// Renders any parametric FloorPlanModel (walls, door/window gaps + swing
// arcs, room labels, bounding dimensions) in the design's original visual
// style. The hardcoded demo apartment is gone — previews use the DEBUG
// FloorPlanModel.sample, real screens pass scanned/synced models.

import SwiftUI

public struct FloorPlan: View {
    private let model: FloorPlanModel
    private let accent: Color
    private let unit: MeasureUnit
    private let showDims: Bool
    private let small: Bool

    /// - Parameters:
    ///   - model: the parametric plan to draw.
    ///   - accent: outline / fill / dim-label tint. Defaults to live theme accent.
    ///   - unit: drives the dimension labels (metric vs imperial).
    ///   - showDims: draw the dimension tick lines + labels. Default true.
    ///   - small: compact variant (thinner walls, no room labels/dims). Default false.
    public init(model: FloorPlanModel,
                accent: Color? = nil,
                unit: MeasureUnit = .metric,
                showDims: Bool = true,
                small: Bool = false) {
        self.model = model
        self.accent = accent ?? Theme.fallback.accent
        self.unit = unit
        self.showDims = showDims
        self.small = small
    }

    /// Maps plan-space meters into a fitted, centered rect with margins for
    /// the dimension rails.
    private struct Mapping {
        let scale: CGFloat
        let ox: CGFloat
        let oy: CGFloat

        init(size: CGSize, planW: Double, planH: Double, margin: CGFloat) {
            let availW = max(1, size.width - margin * 2)
            let availH = max(1, size.height - margin * 2)
            let w = max(planW, 0.01), h = max(planH, 0.01)
            scale = min(availW / CGFloat(w), availH / CGFloat(h))
            ox = (size.width - CGFloat(w) * scale) / 2
            oy = (size.height - CGFloat(h) * scale) / 2
        }

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: ox + CGFloat(x) * scale, y: oy + CGFloat(y) * scale)
        }
    }

    public var body: some View {
        GeometryReader { geo in
            if model.walls.isEmpty {
                emptyState
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                content(Mapping(size: geo.size,
                                planW: model.widthMeters,
                                planH: model.heightMeters,
                                margin: showDims && !small ? 26 : 6))
            }
        }
    }

    private var emptyState: some View {
        Text("NO PLAN")
            .font(Theme.mono(10))
            .tracking(1.5)
            .foregroundStyle(Color.white.opacity(0.35))
    }

    @ViewBuilder
    private func content(_ m: Mapping) -> some View {
        let wallWidth: CGFloat = small ? 2.5 : 4
        ZStack {
            // Room fill (soft accent wash under everything).
            roomFill(m).fill(accent.withA(0.07))

            // Walls.
            wallsPath(m).stroke(accent, style: StrokeStyle(lineWidth: wallWidth,
                                                           lineCap: .round,
                                                           lineJoin: .round))

            // Door / window gaps cut with the surface color, then door swings.
            openingGaps(m, kinds: [.door, .opening])
                .stroke(Color(hex: "#15171c"), lineWidth: wallWidth + 1)
            openingGaps(m, kinds: [.window])
                .stroke(Color.white.opacity(0.45), lineWidth: max(1.5, wallWidth - 2))
            doorSwings(m).stroke(Color.white.opacity(0.3), lineWidth: 1.2)

            if !small {
                roomLabels(m)
            }
            if showDims && !small {
                dimensions(m)
            }
        }
    }

    // MARK: - Geometry

    private func wallsPath(_ m: Mapping) -> Path {
        var p = Path()
        for wall in model.walls {
            p.move(to: m.point(wall.startX, wall.startY))
            p.addLine(to: m.point(wall.endX, wall.endY))
        }
        return p
    }

    private func roomFill(_ m: Mapping) -> Path {
        var p = Path()
        for room in model.rooms where room.polygonX.count >= 3 {
            p.move(to: m.point(room.polygonX[0], room.polygonY[0]))
            for i in 1..<min(room.polygonX.count, room.polygonY.count) {
                p.addLine(to: m.point(room.polygonX[i], room.polygonY[i]))
            }
            p.closeSubpath()
        }
        return p
    }

    /// The opening's segment along its host wall (plan space → view space).
    private func openingSegment(_ opening: FloorPlanModel.Opening,
                                _ m: Mapping) -> (CGPoint, CGPoint)? {
        guard let wall = model.walls.first(where: { $0.id == opening.wallID }),
              wall.lengthMeters > 0 else { return nil }
        let dx = (wall.endX - wall.startX) / wall.lengthMeters
        let dy = (wall.endY - wall.startY) / wall.lengthMeters
        let from = m.point(wall.startX + dx * opening.offset,
                           wall.startY + dy * opening.offset)
        let to = m.point(wall.startX + dx * (opening.offset + opening.width),
                         wall.startY + dy * (opening.offset + opening.width))
        return (from, to)
    }

    private func openingGaps(_ m: Mapping, kinds: Set<FloorPlanModel.OpeningKind>) -> Path {
        var p = Path()
        for opening in model.openings where kinds.contains(opening.kind) {
            if let (from, to) = openingSegment(opening, m) {
                p.move(to: from)
                p.addLine(to: to)
            }
        }
        return p
    }

    private func doorSwings(_ m: Mapping) -> Path {
        var p = Path()
        for opening in model.openings where opening.kind == .door {
            if let (from, to) = openingSegment(opening, m) {
                let radius = hypot(to.x - from.x, to.y - from.y)
                guard radius > 0 else { continue }
                let hingeAngle = atan2(to.y - from.y, to.x - from.x)
                p.move(to: to)
                p.addArc(center: from, radius: radius,
                         startAngle: .radians(hingeAngle),
                         endAngle: .radians(hingeAngle + .pi / 2),
                         clockwise: false)
            }
        }
        return p
    }

    private func roomLabels(_ m: Mapping) -> some View {
        ForEach(model.rooms) { room in
            let n = min(room.polygonX.count, room.polygonY.count)
            if n >= 3 {
                let cx = room.polygonX.prefix(n).reduce(0, +) / Double(n)
                let cy = room.polygonY.prefix(n).reduce(0, +) / Double(n)
                Text(room.label)
                    .font(Theme.mono(11))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .position(m.point(cx, cy))
            }
        }
    }

    private func dimensions(_ m: Mapping) -> some View {
        let topLeft = m.point(0, 0)
        let topRight = m.point(model.widthMeters, 0)
        let bottomLeft = m.point(0, model.heightMeters)
        return ZStack {
            // top dimension line + ticks
            Path { p in
                p.move(to: CGPoint(x: topLeft.x, y: topLeft.y - 14))
                p.addLine(to: CGPoint(x: topRight.x, y: topRight.y - 14))
                p.move(to: CGPoint(x: topLeft.x, y: topLeft.y - 18))
                p.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y - 10))
                p.move(to: CGPoint(x: topRight.x, y: topRight.y - 18))
                p.addLine(to: CGPoint(x: topRight.x, y: topRight.y - 10))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 1)
            Text(lengthLabel(model.widthMeters))
                .font(Theme.mono(10.5))
                .foregroundStyle(accent)
                .position(x: (topLeft.x + topRight.x) / 2, y: topLeft.y - 24)

            // left dimension line + rotated label
            Path { p in
                p.move(to: CGPoint(x: topLeft.x - 14, y: topLeft.y))
                p.addLine(to: CGPoint(x: bottomLeft.x - 14, y: bottomLeft.y))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 1)
            Text(lengthLabel(model.heightMeters))
                .font(Theme.mono(10.5))
                .foregroundStyle(accent)
                .rotationEffect(.degrees(-90))
                .position(x: topLeft.x - 24, y: (topLeft.y + bottomLeft.y) / 2)
        }
    }

    /// Dimension label respecting the unit system.
    private func lengthLabel(_ meters: Double) -> String {
        unit == .imperial
            ? UnitFormat.lengthFractional(meters, unit: .imperial)
            : String(format: "%.2fm", meters)
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color(hex: "#101216")
        FloorPlan(model: .sample, accent: AccentOption.blue.color, unit: .metric)
            .padding(24)
    }
    .frame(width: 360, height: 340)
}
#endif
