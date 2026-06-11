// MeasureTypes.swift — TapeScan measurement domain vocabulary (M2).
//
// Pure value types shared by the AR services, the Measure screens, history
// persistence, and cloud sync. World coordinates are ARKit world space in
// METERS. These types are defined by the architecture contracts doc
// (docs/superpowers/specs/2026-06-10-tapescan-architecture-contracts.md);
// change them there first.

import Foundation
import simd

/// The four capture modes of the Measure tab.
public enum MeasureMode: String, Codable, CaseIterable, Sendable {
    case distance, area, volume, angle
}

/// A user-placed point in AR world space (meters).
public struct WorldPoint: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var x: Float
    public var y: Float
    public var z: Float

    public var position: SIMD3<Float> { .init(x, y, z) }

    public init(id: UUID = UUID(), position: SIMD3<Float>) {
        self.id = id
        self.x = position.x
        self.y = position.y
        self.z = position.z
    }
}

/// A world point projected into view coordinates for the HUD overlay.
/// Refreshed every frame by the AR service; `id` matches the source
/// ``WorldPoint``.
public struct ProjectedPoint: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var screen: CGPoint
    public var isVisible: Bool

    public init(id: UUID, screen: CGPoint, isVisible: Bool) {
        self.id = id
        self.screen = screen
        self.isVisible = isVisible
    }
}

/// The computed measurement for the current point set in a given mode.
/// All values are SI (meters / m² / m³ / degrees); display formatting is
/// `UnitFormat`'s job.
public struct MeasureResult: Codable, Equatable, Sendable {
    public var mode: MeasureMode
    /// Open polyline segment lengths in placement order (meters).
    public var segmentLengths: [Double]
    /// Sum of segments; in `.area` mode includes the closing segment
    /// (i.e. the polygon perimeter).
    public var totalLength: Double
    /// Polygon area (m²) — `.area` and `.volume` modes, ≥3 base points.
    public var area: Double?
    /// Prism volume (m³) — `.volume` mode, ≥4 points (base + apex).
    public var volume: Double?
    /// Angle at the middle vertex of the first three points (degrees) —
    /// `.angle` mode.
    public var angleDegrees: Double?

    public init(mode: MeasureMode,
                segmentLengths: [Double] = [],
                totalLength: Double = 0,
                area: Double? = nil,
                volume: Double? = nil,
                angleDegrees: Double? = nil) {
        self.mode = mode
        self.segmentLengths = segmentLengths
        self.totalLength = totalLength
        self.area = area
        self.volume = volume
        self.angleDegrees = angleDegrees
    }
}
