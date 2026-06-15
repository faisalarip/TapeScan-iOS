// ARKitMeasureService.swift — the real ARKit / RealityKit AR measuring backend.
//
// Owns the ARSession through a RealityKit ARView (hosted on screen by
// ARViewContainer). Device configuration:
//   • LiDAR (supportsSceneReconstruction(.mesh)): sceneReconstruction = .mesh —
//     raycasts resolve against the reconstructed mesh.
//   • Fallback: horizontal + vertical plane detection — raycasts resolve
//     against detected plane geometry, then estimated planes.
// Placed points are world-anchored sphere markers; a session-delegate proxy
// republishes per-frame NORMALIZED (0…1) projected screen coordinates,
// reticle depth, and the mapped tracking quality (ARTrackingMapping.swift).
//
// Honesty guardrails (competitive benchmark): placePoint() rejects raycasts
// beyond 15 m so nonsense numbers are never emitted, and tracking guidance
// strings surface in the HUD instead of silently degrading accuracy.
//
// This file compiles against the Simulator SDK but is never instantiated
// there: MeasureServiceFactory returns SimulatedARMeasureService under
// #if targetEnvironment(simulator).

import ARKit
import Observation
import RealityKit
import simd
import UIKit

@MainActor
@Observable
public final class ARKitMeasureService: ARMeasureService {

    // MARK: - ARMeasureService state

    /// Real hardware capability — true only on LiDAR devices.
    public let lidarAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    public private(set) var tracking: TrackingQuality = .initializing

    public var mode: MeasureMode = .distance {
        didSet { recomputeResult() }
    }

    public var snapEnabled: Bool = true

    public private(set) var points: [WorldPoint] = []
    public private(set) var projected: [ProjectedPoint] = []
    public private(set) var result = MeasureMath.result(mode: .distance, points: [])
    public private(set) var targetDepthMeters: Double?

    public var canUndo: Bool { !points.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Raycast hits beyond this distance are rejected — accuracy degrades
    /// severely at range and emitting a wrong number is worse than a miss.
    private static let maxPlacementDistanceMeters: Float = 15

    // MARK: - AR plumbing

    /// The RealityKit view rendering the camera feed + markers. ARViewContainer
    /// embeds it; this service owns its session and lifecycle.
    public let arView: ARView
    private let sessionProxy = ARSessionProxy()
    @ObservationIgnored private var markerAnchors: [AnchorEntity] = []
    @ObservationIgnored private var redoStack: [WorldPoint] = []
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var frameCounter = 0

    public init() {
        arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        sessionProxy.service = self
        arView.session.delegate = sessionProxy
    }

    // MARK: - Lifecycle

    /// Starts (or resumes) the session. Safe to call redundantly — the
    /// scenePhase observer and the Measure screens' onAppear may overlap.
    public func start() {
        guard !isRunning else { return }
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        if lidarAvailable {
            config.sceneReconstruction = .mesh
        } else {
            config.planeDetection = [.horizontal, .vertical]
        }
        arView.session.run(config)
        isRunning = true
    }

    /// Pauses the session and releases the camera. Safe to call redundantly.
    public func stop() {
        guard isRunning else { return }
        arView.session.pause()
        isRunning = false
        tracking = .initializing
        targetDepthMeters = nil
    }

    // MARK: - Intents

    @discardableResult
    public func placePoint() -> WorldPoint? {
        guard let hit = raycastReticle() else { return nil }
        let column = hit.worldTransform.columns.3
        let hitPosition = SIMD3<Float>(column.x, column.y, column.z)

        // Reject implausible hits instead of emitting nonsense measurements.
        if let camera = arView.session.currentFrame?.camera {
            let cam = camera.transform.columns.3
            let distance = simd_distance(SIMD3<Float>(cam.x, cam.y, cam.z), hitPosition)
            guard distance <= Self.maxPlacementDistanceMeters else { return nil }
        }

        let position = ARPlacement.resolvedPosition(hit: hitPosition,
                                                    existing: points.map(\.position),
                                                    snapEnabled: snapEnabled)
        let point = WorldPoint(position: position)
        points.append(point)
        redoStack.removeAll()
        addMarker(at: position)
        recomputeResult()
        return point
    }

    public func undo() {
        guard let removed = points.popLast() else { return }
        redoStack.append(removed)
        if let anchor = markerAnchors.popLast() {
            arView.scene.removeAnchor(anchor)
        }
        recomputeResult()
    }

    public func redo() {
        guard let point = redoStack.popLast() else { return }
        points.append(point)
        addMarker(at: point.position)
        recomputeResult()
    }

    @discardableResult
    public func finish() -> MeasureResult? {
        guard !points.isEmpty else { return nil }
        let finished = result
        clearPoints()
        return finished
    }

    /// Restore a crash-recovered draft session: re-anchors every point.
    public func load(points restored: [WorldPoint], mode: MeasureMode) {
        clearPoints()
        self.mode = mode
        for point in restored {
            points.append(point)
            addMarker(at: point.position)
        }
        recomputeResult()
    }

    private func clearPoints() {
        points.removeAll()
        projected.removeAll()
        redoStack.removeAll()
        for anchor in markerAnchors {
            arView.scene.removeAnchor(anchor)
        }
        markerAnchors.removeAll()
        recomputeResult()
    }

    // MARK: - Raycasting

    /// Raycasts from the on-screen reticle: detected geometry first (plane
    /// anchors; the LiDAR mesh also answers estimated-plane queries), then
    /// estimated planes as the fallback.
    ///
    /// Fires from where the reticle is actually DRAWN — horizontally centered,
    /// `SceneMapping.reticleAnchorY` (0.47h) down — not the geometric center
    /// (0.50h). The arView and the SwiftUI reticle overlay both ignore the safe
    /// area, so this resolves to the same screen-Y as the crosshair; using midY
    /// dropped placed points ~3% of the screen height *below* the crosshair.
    private func raycastReticle() -> ARRaycastResult? {
        guard arView.bounds.width > 0, arView.bounds.height > 0 else { return nil }
        let target = CGPoint(x: arView.bounds.midX,
                             y: arView.bounds.height * SceneMapping.reticleAnchorY)
        if let hit = arView.raycast(from: target,
                                    allowing: .existingPlaneGeometry,
                                    alignment: .any).first {
            return hit
        }
        return arView.raycast(from: target,
                              allowing: .estimatedPlane,
                              alignment: .any).first
    }

    // MARK: - Markers

    /// Drops a small world-anchored sphere so placed points stay glued to the
    /// real surface (the 2D overlay re-projects them every frame).
    private func addMarker(at position: SIMD3<Float>) {
        let anchor = AnchorEntity(world: position)
        let sphere = ModelEntity(mesh: .generateSphere(radius: 0.006),
                                 materials: [UnlitMaterial(color: .white)])
        anchor.addChild(sphere)
        arView.scene.addAnchor(anchor)
        markerAnchors.append(anchor)
    }

    private func recomputeResult() {
        result = MeasureMath.result(mode: mode, points: points.map(\.position))
    }

    // MARK: - Session events (forwarded by ARSessionProxy on the main thread)

    fileprivate func handle(frame: ARFrame) {
        tracking = TrackingQuality(frame.camera.trackingState)

        // Re-project every placed point into NORMALIZED view coordinates
        // (the protocol contract — overlays map them into their own space).
        let size = arView.bounds.size
        if size.width > 0, size.height > 0 {
            projected = points.map { point in
                if let screen = arView.project(point.position) {
                    return ProjectedPoint(
                        id: point.id,
                        screen: CGPoint(x: screen.x / size.width,
                                        y: screen.y / size.height),
                        isVisible: true)
                }
                return ProjectedPoint(id: point.id, screen: .zero, isVisible: false)
            }
        }

        // Reticle depth — throttled to every 6th frame (~10 Hz at 60 fps); the
        // telemetry readout does not need a raycast per frame.
        frameCounter += 1
        guard frameCounter % 6 == 0 else { return }
        if case .normal = tracking, let hit = raycastReticle() {
            let cam = frame.camera.transform.columns.3
            let hitColumn = hit.worldTransform.columns.3
            targetDepthMeters = Double(simd_distance(
                SIMD3<Float>(cam.x, cam.y, cam.z),
                SIMD3<Float>(hitColumn.x, hitColumn.y, hitColumn.z)))
        } else {
            targetDepthMeters = nil
        }
    }

    fileprivate func handleSessionFailure(_ error: Error) {
        tracking = .notAvailable
        targetDepthMeters = nil
        isRunning = false
    }

    fileprivate func handleInterruption(ended: Bool) {
        tracking = ended ? .initializing : .notAvailable
        if !ended { targetDepthMeters = nil }
    }
}

// MARK: - Session delegate proxy

/// Non-isolated NSObject bridge for ARSessionDelegate. ARSession delivers
/// delegate callbacks on the main thread when `delegateQueue` is nil (the
/// default), so `MainActor.assumeIsolated` re-enters the actor synchronously
/// and safely. Keeping the bridge separate avoids conforming the @MainActor
/// service itself to the non-isolated @objc protocol.
private final class ARSessionProxy: NSObject, ARSessionDelegate {
    weak var service: ARKitMeasureService?

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        MainActor.assumeIsolated { service?.handle(frame: frame) }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        MainActor.assumeIsolated { service?.handleSessionFailure(error) }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        MainActor.assumeIsolated { service?.handleInterruption(ended: false) }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        MainActor.assumeIsolated { service?.handleInterruption(ended: true) }
    }
}
