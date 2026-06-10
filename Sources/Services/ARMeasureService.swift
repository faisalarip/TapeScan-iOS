// ARMeasureService.swift — protocol seam for real ARKit / LiDAR integration.
//
// The UI runs entirely on the SwiftUI `CameraBackdrop` stand-in (no device
// required). When a real AR backend lands, conform to this protocol and inject
// it; the view layer reads `tracking` / `lidarAvailable` and dispatches the
// intents below. NOTHING here imports ARKit, so the app compiles + runs in the
// Simulator.

import Foundation
import CoreGraphics

/// AR tracking quality, surfaced in telemetry strips and the calibrate screen.
public enum TrackingQuality: Sendable {
    case initializing
    case limited
    case normal

    /// 0…1 strength used to fill the little bar meters in the HUD.
    public var strength: Double {
        switch self {
        case .initializing: return 0.25
        case .limited:      return 0.6
        case .normal:       return 1.0
        }
    }
}

/// A placed measurement point in normalized scene space (0…1 on each axis).
public struct MeasurePoint: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var x: CGFloat
    public var y: CGFloat
    public init(id: UUID = UUID(), x: CGFloat, y: CGFloat) {
        self.id = id; self.x = x; self.y = y
    }
}

/// The AR backend seam. Implementations may wrap ARKit + a LiDAR depth provider;
/// the default ``SimulatedARMeasureService`` provides static values for the
/// Simulator / previews.
@MainActor
public protocol ARMeasureService: AnyObject {
    /// Whether device LiDAR is available + active. Drives precision + fallback UI.
    var lidarAvailable: Bool { get }
    /// Current tracking quality.
    var tracking: TrackingQuality { get }
    /// Estimated depth to the reticle target, in meters (for the telemetry strip).
    var targetDepthMeters: Double { get }
    /// Number of points currently placed in the active measurement. Views read
    /// this to make the capture controls *visibly* respond (e.g. the "N PTS"
    /// readout) while the static design geometry stays put.
    var placedCount: Int { get }

    /// Begin an AR session (no-op in the simulated backend).
    func start()
    /// Tear down the session and release the camera.
    func stop()
    /// Drop a measurement point at the current reticle target.
    @discardableResult func placePoint() -> MeasurePoint
    /// Remove the most recently placed point.
    func undo()
    /// Finalize the current measurement.
    func finish()
}

/// Default no-hardware backend. Mirrors the design's static AR mock so the whole
/// app is fully navigable in the Simulator.
///
/// The mock seeds the canonical resting point count (the design's 3-node
/// Precision HUD), so the AR readout opens on the verified 1:1 state. Each
/// place/undo/finish updates `placedCount`; the Measure views mirror that into
/// local `@State` so the capture controls *visibly* respond on tap.
@MainActor
public final class SimulatedARMeasureService: ARMeasureService {
    public let lidarAvailable: Bool
    public let tracking: TrackingQuality
    public let targetDepthMeters: Double

    /// Placed points. Seeded with the canonical resting count so the AR readout
    /// opens on the verified design state (e.g. "3 PTS").
    private var points: [MeasurePoint]

    /// Live count of placed points (drives the "N PTS" readout).
    public var placedCount: Int { points.count }

    /// - Parameter seededPoints: resting point count to start from (design 1:1
    ///   default is 3, matching the Precision HUD's three-node polyline).
    public nonisolated init(lidarAvailable: Bool = true,
                            tracking: TrackingQuality = .normal,
                            targetDepthMeters: Double = 1.82,
                            seededPoints: Int = 3) {
        self.lidarAvailable = lidarAvailable
        self.tracking = tracking
        self.targetDepthMeters = targetDepthMeters
        self.points = (0..<max(0, seededPoints)).map { _ in MeasurePoint(x: 0.5, y: 0.47) }
    }

    public func start() {}
    public func stop() {}

    @discardableResult
    public func placePoint() -> MeasurePoint {
        let p = MeasurePoint(x: 0.5, y: 0.47)
        points.append(p)
        return p
    }

    public func undo() { _ = points.popLast() }
    public func finish() { points.removeAll() }
}
