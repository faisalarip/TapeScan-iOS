// MeasureScene.swift — the shared AR geometry overlay for the Measure hero.
//
// Ported 1:1 from measure.jsx `MeasureScene`: a node/edge polyline (or closed
// polygon for area) drawn over the AR floor, with HTML-style value pills pinned
// to segment midpoints, an optional angle arc, an active dashed lead line, and a
// big centered area readout.
//
// COORDINATE SPACE
// The design authors all positions in a fixed 402 × 874 canvas with the SVG set
// to `preserveAspectRatio="none"` — i.e. the scene STRETCHES to fill whatever
// the device viewport is. We reproduce that exactly with a `SceneMapping` that
// linearly maps design points into the live `GeometryReader` size. Keeping the
// math in a value type (not inline in the ViewBuilder closure) avoids the
// "closure containing a declaration cannot be used with result builder" error.

import SwiftUI

// MARK: - Design-space model

/// A point in the design's fixed 402 × 874 canvas.
struct ScenePoint: Hashable {
    var x: CGFloat
    var y: CGFloat
}

/// A value pill pinned at a design-space anchor (segment midpoint / label).
struct SceneSegment: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var text: String
    var sub: String? = nil
    var active: Bool = false
}

/// A big centered area readout (value + accent sub-caption) at a design anchor.
struct SceneArea {
    var x: CGFloat
    var y: CGFloat
    var text: String
    var sub: String
}

/// An angle annotation: an SVG-arc-equivalent plus a mono value pill.
struct SceneAngle {
    /// Arc geometry in design space: vertex, radius, start/end angle (radians).
    var center: ScenePoint
    var radius: CGFloat
    var startAngle: Angle
    var endAngle: Angle
    /// Pill position + text.
    var x: CGFloat
    var y: CGFloat
    var text: String
}

/// Linear map from the design's 402 × 874 canvas to the live viewport.
/// Mirrors SVG `preserveAspectRatio="none"` (independent x / y scaling).
struct SceneMapping {
    static let designW: CGFloat = 402
    static let designH: CGFloat = 874

    let size: CGSize

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x / Self.designW * size.width,
                y: y / Self.designH * size.height)
    }
    func point(_ p: ScenePoint) -> CGPoint { point(p.x, p.y) }

    func scaleX(_ v: CGFloat) -> CGFloat { v / Self.designW * size.width }
    func scaleY(_ v: CGFloat) -> CGFloat { v / Self.designH * size.height }
}

// MARK: - Scene overlay

/// Renders the measurement geometry + pills over the camera/AR backdrop.
struct MeasureScene: View {
    let accent: Color
    var pts: [ScenePoint]
    var segs: [SceneSegment] = []
    var area: SceneArea? = nil
    var angle: SceneAngle? = nil
    /// Active dashed "lead" line from the last node to the live reticle target.
    var activeTo: ScenePoint? = nil

    var body: some View {
        GeometryReader { geo in
            content(SceneMapping(size: geo.size))
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func content(_ m: SceneMapping) -> some View {
        ZStack(alignment: .topLeading) {
            // Edges / fill (Canvas reproduces the SVG polyline / polygon + glow).
            Canvas { ctx, _ in
                guard !pts.isEmpty else { return }
                let mapped = pts.map { m.point($0) }

                var poly = Path()
                poly.move(to: mapped[0])
                for p in mapped.dropFirst() { poly.addLine(to: p) }

                if area != nil {
                    poly.closeSubpath()
                    // Soft accent area fill (accent @ 0.16).
                    ctx.fill(poly, with: .color(accent.withA(0.16)))
                }

                // Glow underlay (approximates the SVG feGaussianBlur stack).
                ctx.stroke(poly, with: .color(accent.withA(0.35)),
                           style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                ctx.stroke(poly, with: .color(accent),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Active dashed lead line.
                if let to = activeTo, let last = mapped.last {
                    var lead = Path()
                    lead.move(to: last)
                    lead.addLine(to: m.point(to))
                    ctx.stroke(lead, with: .color(accent.withA(0.7)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 6]))
                }

                // Angle arc.
                if let a = angle {
                    var arc = Path()
                    arc.addArc(center: m.point(a.center),
                               radius: m.scaleX(a.radius),
                               startAngle: a.startAngle,
                               endAngle: a.endAngle,
                               clockwise: false)
                    ctx.stroke(arc, with: .color(.white.opacity(0.85)), lineWidth: 1.4)
                }

                // Nodes: dark disc, accent ring, accent core.
                for p in mapped {
                    let ring = CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)
                    ctx.fill(Path(ellipseIn: ring),
                             with: .color(Color(.sRGB, red: 10/255, green: 12/255, blue: 15/255, opacity: 0.85)))
                    ctx.stroke(Path(ellipseIn: ring), with: .color(accent), lineWidth: 2)
                    let core = CGRect(x: p.x - 2.4, y: p.y - 2.4, width: 4.8, height: 4.8)
                    ctx.fill(Path(ellipseIn: core), with: .color(accent))
                }
            }

            // Segment value pills.
            ForEach(segs) { s in
                ValuePill(text: s.text, sub: s.sub, accent: accent, active: s.active)
                    .position(m.point(s.x, s.y))
            }

            // Big centered area readout.
            if let a = area {
                VStack(spacing: 2) {
                    Text(a.text)
                        .font(Theme.mono(26, weight: .bold))
                        .foregroundStyle(Color.white)
                        .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
                    Text(a.sub)
                        .font(Theme.mono(10))
                        .tracking(1.5)
                        .foregroundStyle(accent.withA(0.95))
                }
                .fixedSize()
                .position(m.point(a.x, a.y))
            }

            // Angle value pill (mono).
            if let a = angle {
                ValuePill(text: a.text, accent: accent, mono: true)
                    .position(m.point(a.x, a.y))
            }
        }
        .frame(width: m.size.width, height: m.size.height)
    }
}

// MARK: - Mode display helpers (ported from MEASURE_MODES + MODE_* maps)

/// UI affordances for the domain ``MeasureMode`` (declared in
/// Sources/Domain/MeasureTypes.swift) — icon names and display labels for the
/// bottom mode switch / text tabs.
extension MeasureMode: Identifiable {
    public var id: String { rawValue }

    /// `Icon` name in the shared icon set.
    var icon: String { rawValue }
    /// Title-case label ("Distance").
    var label: String { rawValue.capitalized }
    /// Upper-case chip label ("DISTANCE").
    var chipLabel: String { rawValue.uppercased() }
    /// Big-readout caption per mode (Direction A) — MODE_READOUT.
    var readoutLabel: String {
        switch self {
        case .distance: return "CURRENT SPAN"
        case .area:     return "FLOOR AREA"
        case .volume:   return "VOLUME"
        case .angle:    return "ANGLE"
        }
    }
}
