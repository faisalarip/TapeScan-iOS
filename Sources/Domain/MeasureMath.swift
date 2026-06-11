// MeasureMath.swift — pure measurement geometry (M2).
//
// Every number the app displays flows through these functions, so they are
// fully unit-tested (Tests/TapeScanTests/MeasureMathTests.swift) and contain
// no ARKit, UI, or state dependencies. Inputs are ARKit world-space points in
// METERS; outputs are SI doubles.

import Foundation
import simd

public enum MeasureMath {

    /// Euclidean distance between two world points (meters).
    public static func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Double {
        Double(simd_distance(a, b))
    }

    /// Total length of an open polyline (meters). Fewer than 2 points → 0.
    public static func polylineLength(_ pts: [SIMD3<Float>]) -> Double {
        guard pts.count >= 2 else { return 0 }
        return zip(pts, pts.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    /// Area of the planar polygon through `pts` (m²), computed as half the
    /// magnitude of the summed cross products — exact for planar polygons in
    /// any orientation (the "shoelace on the polygon's plane"). Fewer than 3
    /// points → 0.
    public static func polygonArea(_ pts: [SIMD3<Float>]) -> Double {
        guard pts.count >= 3 else { return 0 }
        // Sum relative to the centroid for numerical stability far from origin.
        let centroid = pts.reduce(SIMD3<Float>.zero, +) / Float(pts.count)
        var normalSum = SIMD3<Double>.zero
        for i in 0..<pts.count {
            let a = SIMD3<Double>(pts[i] - centroid)
            let b = SIMD3<Double>(pts[(i + 1) % pts.count] - centroid)
            normalSum += cross(a, b)
        }
        return 0.5 * simd_length(normalSum)
    }

    /// Volume of a prism: `polygonArea(base)` × perpendicular height of
    /// `apex` above the base's plane (m³). Degenerate base → 0.
    public static func prismVolume(base: [SIMD3<Float>], apex: SIMD3<Float>) -> Double {
        guard base.count >= 3 else { return 0 }
        let area = polygonArea(base)
        guard area > 0 else { return 0 }
        // Unit normal of the base plane via the same cross-product sum.
        let centroid = base.reduce(SIMD3<Float>.zero, +) / Float(base.count)
        var normalSum = SIMD3<Double>.zero
        for i in 0..<base.count {
            let a = SIMD3<Double>(base[i] - centroid)
            let b = SIMD3<Double>(base[(i + 1) % base.count] - centroid)
            normalSum += cross(a, b)
        }
        let n = simd_normalize(normalSum)
        let height = abs(dot(SIMD3<Double>(apex - centroid), n))
        return area * height
    }

    /// Angle ∠AVC at `vertex`, in degrees ∈ [0, 180]. Degenerate legs → 0.
    public static func angleDegrees(a: SIMD3<Float>, vertex: SIMD3<Float>, c: SIMD3<Float>) -> Double {
        let u = SIMD3<Double>(a - vertex)
        let v = SIMD3<Double>(c - vertex)
        let lu = simd_length(u), lv = simd_length(v)
        guard lu > 0, lv > 0 else { return 0 }
        let cosine = max(-1.0, min(1.0, dot(u, v) / (lu * lv)))
        return acos(cosine) * 180.0 / .pi
    }

    /// Nearest point of `existing` within `threshold` meters of `candidate`,
    /// or nil if none qualifies. Used for point snapping (closes polygons
    /// cleanly and welds repeat taps).
    public static func snap(_ candidate: SIMD3<Float>,
                            to existing: [SIMD3<Float>],
                            threshold: Float) -> SIMD3<Float>? {
        var best: (point: SIMD3<Float>, dist: Float)?
        for p in existing {
            let d = simd_distance(candidate, p)
            if d <= threshold, d < (best?.dist ?? .greatestFiniteMagnitude) {
                best = (p, d)
            }
        }
        return best?.point
    }

    /// Aggregate the placed points into the mode's ``MeasureResult``.
    ///
    /// Conventions (mirrored by the Measure HUD):
    /// - `.distance`: open polyline; total = sum of segments.
    /// - `.area`: points form a closed polygon; total = perimeter
    ///   (segments + closing edge), `area` set for ≥3 points.
    /// - `.volume`: last point is the apex; the rest form the base polygon.
    /// - `.angle`: angle at the middle vertex of the first three points.
    public static func result(mode: MeasureMode, points: [SIMD3<Float>]) -> MeasureResult {
        var segments: [Double] = []
        if points.count >= 2 {
            segments = zip(points, points.dropFirst()).map { distance($0, $1) }
        }
        var total = segments.reduce(0, +)
        var area: Double?
        var volume: Double?
        var angle: Double?

        switch mode {
        case .distance:
            break
        case .area:
            if points.count >= 3 {
                area = polygonArea(points)
                total += distance(points[points.count - 1], points[0]) // closing edge
            }
        case .volume:
            if points.count >= 4 {
                let base = Array(points.dropLast())
                area = polygonArea(base)
                volume = prismVolume(base: base, apex: points[points.count - 1])
            } else if points.count >= 3 {
                area = polygonArea(points)
            }
        case .angle:
            if points.count >= 3 {
                angle = angleDegrees(a: points[0], vertex: points[1], c: points[2])
            }
        }
        return MeasureResult(mode: mode,
                             segmentLengths: segments,
                             totalLength: total,
                             area: area,
                             volume: volume,
                             angleDegrees: angle)
    }
}
