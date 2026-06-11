// ARPlacement.swift — pure, snap-aware placement resolution for AR raycast hits.
//
// Extracted from ARKitMeasureService.placePoint() so the snapping decision is
// unit-testable without an ARSession. Snapping pulls a new point onto the
// nearest existing point within a small world-space threshold, which also
// closes polygons cleanly in area/volume modes.

import simd

public enum ARPlacement {
    /// World-space snap radius in meters (2 cm).
    public static let snapThresholdMeters: Float = 0.02

    /// Resolves the final world position for a raycast hit: when snapping is
    /// enabled and an existing point lies within ``snapThresholdMeters``,
    /// returns that point; otherwise returns the hit unchanged.
    public static func resolvedPosition(hit: SIMD3<Float>,
                                        existing: [SIMD3<Float>],
                                        snapEnabled: Bool) -> SIMD3<Float> {
        guard snapEnabled,
              let snapped = MeasureMath.snap(hit, to: existing, threshold: snapThresholdMeters)
        else { return hit }
        return snapped
    }
}
