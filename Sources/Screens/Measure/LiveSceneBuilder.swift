// LiveSceneBuilder.swift — bridges live AR service geometry into the
// MeasureScene design-space overlay (M2).
//
// The service reports normalized (0…1) screen projections; MeasureScene
// renders design-space (402 × 874) anchors. This builder maps projections into
// design space and derives the per-segment pills, area readout, and angle arc
// from the live MeasureResult — replacing every hardcoded scene literal.

import SwiftUI

/// The fully derived overlay inputs for one frame.
struct LiveScene {
    var pts: [ScenePoint] = []
    var segs: [SceneSegment] = []
    var area: SceneArea?
    var angle: SceneAngle?
}

@MainActor
enum LiveSceneBuilder {

    /// Build the overlay for the service's current points + result.
    static func build(service: any ARMeasureService, unit: MeasureUnit) -> LiveScene {
        let pts = service.projected.map {
            ScenePoint(x: $0.screen.x * SceneMapping.designW,
                       y: $0.screen.y * SceneMapping.designH)
        }
        let result = service.result
        var scene = LiveScene(pts: pts)

        // Segment value pills at design-space midpoints; the newest is active.
        for (i, length) in result.segmentLengths.enumerated() where i + 1 < pts.count {
            scene.segs.append(SceneSegment(
                x: (pts[i].x + pts[i + 1].x) / 2,
                y: (pts[i].y + pts[i + 1].y) / 2 - 14,
                text: UnitFormat.lengthFractional(length, unit: unit),
                active: i == result.segmentLengths.count - 1))
        }

        // Closed polygon extras for area/volume modes.
        if let area = result.area, pts.count >= 3 {
            let closing = result.totalLength - result.segmentLengths.reduce(0, +)
            if service.mode == .area, closing > 0, let first = pts.first, let last = pts.last {
                scene.segs.append(SceneSegment(
                    x: (first.x + last.x) / 2,
                    y: (first.y + last.y) / 2 - 14,
                    text: UnitFormat.lengthFractional(closing, unit: unit)))
            }
            if service.mode == .area || service.mode == .volume {
                let rawCx = pts.map(\.x).reduce(0, +) / CGFloat(pts.count)
                let rawCy = pts.map(\.y).reduce(0, +) / CGFloat(pts.count)
                // Clamp the readout center to a safe inset so it never clips at the
                // viewport edge when the polygon centroid is near the frame border.
                let cx = min(max(rawCx, 80), SceneMapping.designW - 80)
                let cy = min(max(rawCy, 120), SceneMapping.designH - 200)
                let formatted = UnitFormat.area(area, unit).components(separatedBy: " ")
                scene.area = SceneArea(
                    x: cx, y: cy,
                    text: formatted.first ?? "",
                    sub: (formatted.dropFirst().first ?? "").uppercased() + " · FLOOR")
            }
        }

        // Angle arc + pill at the middle vertex of the first three points.
        if service.mode == .angle, pts.count >= 3, let degrees = result.angleDegrees {
            let v = pts[1]
            let start = atan2(pts[0].y - v.y, pts[0].x - v.x)
            let end = atan2(pts[2].y - v.y, pts[2].x - v.x)
            scene.angle = SceneAngle(
                center: v, radius: 28,
                startAngle: .radians(start), endAngle: .radians(end),
                x: v.x + 16, y: v.y - 10,
                text: UnitFormat.angle(degrees))
        }

        return scene
    }
}
