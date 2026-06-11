// ARPlacementTests.swift — snap-aware raycast position resolution (pure parts).

import XCTest
@testable import TapeScan

final class ARPlacementTests: XCTestCase {

    private let existing: [SIMD3<Float>] = [
        SIMD3<Float>(0, 0, 0),
        SIMD3<Float>(1, 0, 0),
    ]

    func testSnapsToNearbyPointWhenEnabled() {
        let hit = SIMD3<Float>(1.015, 0, 0)   // 15 mm from (1,0,0) — inside the 20 mm threshold
        let resolved = ARPlacement.resolvedPosition(hit: hit, existing: existing, snapEnabled: true)
        XCTAssertEqual(resolved, SIMD3<Float>(1, 0, 0))
    }

    func testDoesNotSnapBeyondThreshold() {
        let hit = SIMD3<Float>(1.05, 0, 0)    // 50 mm away — outside the 20 mm threshold
        let resolved = ARPlacement.resolvedPosition(hit: hit, existing: existing, snapEnabled: true)
        XCTAssertEqual(resolved, hit)
    }

    func testDoesNotSnapWhenDisabled() {
        let hit = SIMD3<Float>(1.001, 0, 0)   // 1 mm away, but snapping is off
        let resolved = ARPlacement.resolvedPosition(hit: hit, existing: existing, snapEnabled: false)
        XCTAssertEqual(resolved, hit)
    }

    func testNoExistingPointsReturnsHit() {
        let hit = SIMD3<Float>(0.5, 0.5, 0.5)
        let resolved = ARPlacement.resolvedPosition(hit: hit, existing: [], snapEnabled: true)
        XCTAssertEqual(resolved, hit)
    }

    func testSnapsToNearestOfSeveral() {
        let hit = SIMD3<Float>(0.99, 0, 0)    // 10 mm from (1,0,0), 990 mm from the origin
        let resolved = ARPlacement.resolvedPosition(hit: hit, existing: existing, snapEnabled: true)
        XCTAssertEqual(resolved, SIMD3<Float>(1, 0, 0))
    }

    func testThresholdConstantIsTwoCentimeters() {
        XCTAssertEqual(ARPlacement.snapThresholdMeters, 0.02)
    }
}
