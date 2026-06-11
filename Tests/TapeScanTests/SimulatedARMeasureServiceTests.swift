// SimulatedARMeasureServiceTests.swift — behavior contract for the
// Simulator/preview AR backend (M2). The protocol semantics pinned here
// (place/undo/redo stacks, live result recompute, finish returning the final
// result, draft restore via load) are exactly what ARKitMeasureService (M4)
// must also satisfy.

import XCTest
@testable import TapeScan

@MainActor
final class SimulatedARMeasureServiceTests: XCTestCase {

    func testSeededStateMatchesTheDesign() {
        let s = SimulatedARMeasureService()
        XCTAssertEqual(s.points.count, 3)
        XCTAssertEqual(s.projected.count, 3)
        XCTAssertTrue(s.lidarAvailable)
        // Seeded geometry reproduces the design readouts: 2.34 m + 1.62 m
        // segments, 118.4° vertex, 3.96 m total.
        XCTAssertEqual(s.result.segmentLengths[0], 2.34, accuracy: 0.005)
        XCTAssertEqual(s.result.segmentLengths[1], 1.62, accuracy: 0.005)
        XCTAssertEqual(s.result.totalLength, 3.96, accuracy: 0.01)
        s.mode = .angle
        XCTAssertEqual(s.result.angleDegrees ?? -1, 118.4, accuracy: 0.5)
    }

    func testPlaceUndoRedo() {
        let s = SimulatedARMeasureService()
        let before = s.points.count
        XCTAssertNotNil(s.placePoint())
        XCTAssertEqual(s.points.count, before + 1)
        XCTAssertTrue(s.canUndo)
        XCTAssertFalse(s.canRedo)

        s.undo()
        XCTAssertEqual(s.points.count, before)
        XCTAssertTrue(s.canRedo)

        s.redo()
        XCTAssertEqual(s.points.count, before + 1)
        XCTAssertFalse(s.canRedo)

        // A new placement clears the redo stack.
        s.undo()
        _ = s.placePoint()
        XCTAssertFalse(s.canRedo)
    }

    func testResultRecomputesOnModeChange() {
        let s = SimulatedARMeasureService()
        s.mode = .area
        XCTAssertEqual(s.result.mode, .area)
        XCTAssertNotNil(s.result.area)
        s.mode = .distance
        XCTAssertNil(s.result.area)
    }

    func testFinishReturnsResultAndClears() {
        let s = SimulatedARMeasureService()
        let result = s.finish()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalLength ?? 0, 3.96, accuracy: 0.01)
        XCTAssertTrue(s.points.isEmpty)
        XCTAssertTrue(s.projected.isEmpty)
        XCTAssertNil(s.finish(), "finishing an empty session returns nil")
    }

    func testLoadRestoresDraft() {
        let s = SimulatedARMeasureService()
        _ = s.finish()
        let draft = [WorldPoint(position: .init(0, 0, 0)),
                     WorldPoint(position: .init(1.5, 0, 0))]
        s.load(points: draft, mode: .area)
        XCTAssertEqual(s.points, draft)
        XCTAssertEqual(s.mode, .area)
        XCTAssertEqual(s.projected.count, 2)
        XCTAssertEqual(s.result.segmentLengths.first ?? 0, 1.5, accuracy: 1e-5)
    }

    func testSnapWeldsNearMissToExistingPoint() {
        // Arrange points so the next simulated target (last + walkOffsets[0]
        // + 1.5 cm jitter) lands within the 2 cm threshold of point `a`.
        let a = WorldPoint(position: .init(-1.2, 0, 0.5))
        let b = WorldPoint(position: .init(0, 0, 0))

        let s = SimulatedARMeasureService()
        _ = s.finish()
        s.load(points: [a, b], mode: .area)
        s.snapEnabled = true
        let welded = s.placePoint()
        XCTAssertEqual(welded?.position, a.position, "near-miss target welds to the existing point")

        _ = s.finish()
        s.load(points: [a, b], mode: .area)
        s.snapEnabled = false
        let raw = s.placePoint()
        XCTAssertNotEqual(raw?.position, a.position, "without snapping the jittered target stays raw")
    }
}
