// ARMeasureService.swift — the AR backend seam (M2 contract).
//
// The protocol carries real geometry: world-space points, per-frame screen
// projections, and a live MeasureResult computed by MeasureMath. Views render
// whatever the service reports — no design literals. Implementations:
//   • SimulatedARMeasureService (below) — Simulator/previews; deterministic
//     geometry seeded to reproduce the design's canonical readouts.
//   • ARKitMeasureService (M4) — ARSession + RealityKit on device.
// NOTHING here imports ARKit, so the app compiles + runs in the Simulator.

import Foundation
import CoreGraphics
import Observation
import simd

/// AR tracking quality, surfaced in telemetry strips and the calibrate screen.
public enum TrackingQuality: Equatable, Sendable {
    case initializing
    case limited
    case normal
    case notAvailable

    /// 0…1 strength used to fill the little bar meters in the HUD.
    public var strength: Double {
        switch self {
        case .notAvailable: return 0.1
        case .initializing: return 0.25
        case .limited:      return 0.6
        case .normal:       return 1.0
        }
    }
}

/// The AR backend seam. `projected` coordinates are NORMALIZED (0…1 on each
/// axis of the camera viewport); views map them into their own space.
@MainActor
public protocol ARMeasureService: AnyObject, Observable {
    /// Whether device LiDAR is available + active. Drives precision + fallback UI.
    var lidarAvailable: Bool { get }
    /// Current tracking quality.
    var tracking: TrackingQuality { get }
    /// Active capture mode; setting it recomputes ``result``.
    var mode: MeasureMode { get set }
    /// Snap new points to existing ones within a small world threshold.
    var snapEnabled: Bool { get set }
    /// Points placed in the current session, in placement order.
    var points: [WorldPoint] { get }
    /// Per-frame screen projections of ``points`` (normalized coordinates).
    var projected: [ProjectedPoint] { get }
    /// Live measurement for the current mode + points (SI units).
    var result: MeasureResult { get }
    /// Depth to the reticle target in meters; nil before tracking settles.
    var targetDepthMeters: Double? { get }
    var canUndo: Bool { get }
    var canRedo: Bool { get }

    /// Begin the AR session (no-op in the simulated backend).
    func start()
    /// Tear down the session and release the camera.
    func stop()
    /// Drop a point at the current reticle target; nil if the raycast missed.
    @discardableResult func placePoint() -> WorldPoint?
    /// Remove the most recently placed point (redoable).
    func undo()
    /// Re-place the most recently undone point.
    func redo()
    /// Finalize the session: returns the final result for persistence (nil if
    /// nothing was measured) and clears all points.
    @discardableResult func finish() -> MeasureResult?
    /// Restore a crash-recovered draft session.
    func load(points: [WorldPoint], mode: MeasureMode)
}

/// Picks the AR backend for the current run environment. M4 swaps the device
/// branch to `ARKitMeasureService`. MainActor-isolated; view inits that use it
/// as a default argument are annotated @MainActor (SE-0411 isolated defaults).
public enum MeasureServiceFactory {
    @MainActor
    public static func make() -> any ARMeasureService {
        // M4: #if targetEnvironment(simulator) → simulated; #else → ARKit.
        SimulatedARMeasureService()
    }
}

/// Default no-hardware backend for the Simulator and previews.
///
/// Deterministic by design (no randomness — workflow/test reproducibility):
/// the seeded three-point polyline reproduces the design's canonical readouts
/// (2.34 m + 1.62 m segments, 118.4° vertex, 3.96 m total), and subsequent
/// placements walk a fixed offset table.
@MainActor
@Observable
public final class SimulatedARMeasureService: ARMeasureService {

    public let lidarAvailable: Bool
    public private(set) var tracking: TrackingQuality
    public var snapEnabled: Bool = true

    public var mode: MeasureMode = .distance

    /// Placed points paired with their normalized screen positions.
    private var placed: [(point: WorldPoint, screen: CGPoint)] = []
    private var redoStack: [(point: WorldPoint, screen: CGPoint)] = []

    public var points: [WorldPoint] { placed.map(\.point) }
    public var projected: [ProjectedPoint] {
        placed.map { ProjectedPoint(id: $0.point.id, screen: $0.screen, isVisible: true) }
    }
    public var result: MeasureResult {
        MeasureMath.result(mode: mode, points: placed.map(\.point.position))
    }

    public var targetDepthMeters: Double? { 1.82 }
    public var canUndo: Bool { !placed.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Where the simulated reticle "hits" for the next placement: a fixed
    /// world target derived from the placement index, cycling a small table.
    private var placementIndex: Int = 0

    /// Design-canonical seeded geometry (see file header).
    private static let seedWorld: [SIMD3<Float>] = [
        .init(0, 0, 0),
        .init(2.34, 0, 0),
        .init(3.111, 0, 1.425),
    ]
    /// Normalized projections of the seeds (the design's 402×874 anchors).
    private static let seedScreens: [CGPoint] = [
        .init(x: 70 / 402, y: 560 / 874),
        .init(x: 300 / 402, y: 600 / 874),
        .init(x: 214 / 402, y: 752 / 874),
    ]
    /// Offset table for additional simulated placements (meters).
    private static let walkOffsets: [SIMD3<Float>] = [
        .init(-1.2, 0, 0.5), .init(0.9, 0, 0.8), .init(0.7, 0, -1.1), .init(-1.0, 0, -0.4),
    ]
    /// Normalized screen slots for additional placements.
    private static let walkScreens: [CGPoint] = [
        .init(x: 0.32, y: 0.62), .init(x: 0.62, y: 0.74), .init(x: 0.72, y: 0.55), .init(x: 0.40, y: 0.50),
    ]

    /// - Parameter seeded: start from the design's canonical 3-point polyline
    ///   (previews/Simulator open on the verified design state).
    public init(lidarAvailable: Bool = true,
                tracking: TrackingQuality = .normal,
                seeded: Bool = true) {
        self.lidarAvailable = lidarAvailable
        self.tracking = tracking
        if seeded {
            placed = zip(Self.seedWorld, Self.seedScreens).map {
                (WorldPoint(position: $0), $1)
            }
        }
    }

    public func start() {}
    public func stop() {}

    @discardableResult
    public func placePoint() -> WorldPoint? {
        // Next simulated reticle target: last point + a fixed offset, plus a
        // constant 1.5 cm "hand shake" so snapping has a real near-miss to
        // weld — mirroring how device raycasts land slightly off.
        let base = placed.last?.point.position ?? .zero
        var target = placed.isEmpty
            ? SIMD3<Float>(0, 0, 0)
            : base + Self.walkOffsets[placementIndex % Self.walkOffsets.count]
                   + SIMD3<Float>(0.015, 0, 0)
        var screen = Self.walkScreens[placementIndex % Self.walkScreens.count]

        if snapEnabled,
           let welded = MeasureMath.snap(target, to: placed.map(\.point.position), threshold: 0.02) {
            target = welded
            // Reuse the welded point's screen anchor so the node overlaps.
            if let existing = placed.first(where: { $0.point.position == welded }) {
                screen = existing.screen
            }
        } else {
            placementIndex += 1
        }

        let point = WorldPoint(position: target)
        placed.append((point, screen))
        redoStack.removeAll()
        return point
    }

    public func undo() {
        guard let last = placed.popLast() else { return }
        redoStack.append(last)
    }

    public func redo() {
        guard let entry = redoStack.popLast() else { return }
        placed.append(entry)
    }

    @discardableResult
    public func finish() -> MeasureResult? {
        guard !placed.isEmpty else { return nil }
        let final = result
        placed.removeAll()
        redoStack.removeAll()
        placementIndex = 0
        return final
    }

    public func load(points: [WorldPoint], mode: MeasureMode) {
        self.mode = mode
        placed = points.enumerated().map { i, p in
            (p, Self.walkScreens[i % Self.walkScreens.count])
        }
        redoStack.removeAll()
        placementIndex = 0
    }
}
