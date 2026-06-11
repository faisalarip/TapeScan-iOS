// ARTrackingMapping.swift — pure ARKit → domain tracking-state mapping.
//
// Kept in its own ARKit-importing file (separate from the session-owning
// ARKitMeasureService) so the mapping is unit-testable on the Simulator,
// where ARKit types compile but sessions never run.

import ARKit

public extension TrackingQuality {
    /// Maps ARKit's camera tracking state onto the domain ``TrackingQuality``.
    /// `.limited(.initializing)` surfaces as `.initializing` (the HUD shows the
    /// same "starting up" treatment); other limited reasons carry a short
    /// user-facing guidance string for the reticle / telemetry strip.
    init(_ trackingState: ARCamera.TrackingState) {
        switch trackingState {
        case .notAvailable:
            self = .notAvailable
        case .normal:
            self = .normal
        case .limited(let reason):
            switch reason {
            case .initializing:
                self = .initializing
            case .excessiveMotion:
                self = .limited(reason: "Move slower")
            case .insufficientFeatures:
                self = .limited(reason: "Aim at a textured surface")
            case .relocalizing:
                self = .limited(reason: "Relocalizing — return to a mapped area")
            @unknown default:
                self = .limited(reason: "Limited tracking")
            }
        }
    }
}
