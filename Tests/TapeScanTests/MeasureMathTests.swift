// MeasureMathTests.swift — exhaustive unit tests for the pure measurement
// math (M2). Every readout in the app flows from these functions; accuracy
// here is the product's accuracy story, so each geometric case is pinned to
// a hand-computed expected value.

import XCTest
import simd
@testable import TapeScan

final class MeasureMathTests: XCTestCase {

    // MARK: - distance

    func testDistanceIsEuclidean() {
        XCTAssertEqual(MeasureMath.distance(.init(0, 0, 0), .init(3, 4, 0)), 5.0, accuracy: 1e-6)
        XCTAssertEqual(MeasureMath.distance(.init(1, 1, 1), .init(1, 1, 1)), 0.0, accuracy: 1e-9)
    }

    // MARK: - polylineLength

    func testPolylineLengthSumsSegments() {
        let pts: [SIMD3<Float>] = [.init(0, 0, 0), .init(3, 4, 0), .init(3, 4, 12)]
        XCTAssertEqual(MeasureMath.polylineLength(pts), 17.0, accuracy: 1e-5)
    }

    func testPolylineLengthDegenerateInputs() {
        XCTAssertEqual(MeasureMath.polylineLength([]), 0.0)
        XCTAssertEqual(MeasureMath.polylineLength([.init(1, 2, 3)]), 0.0)
    }

    // MARK: - polygonArea

    func testSquareAreaOnHorizontalPlane() {
        // 2 m × 2 m square on the XZ plane (constant y — a floor).
        let pts: [SIMD3<Float>] = [
            .init(0, 0, 0), .init(2, 0, 0), .init(2, 0, 2), .init(0, 0, 2),
        ]
        XCTAssertEqual(MeasureMath.polygonArea(pts), 4.0, accuracy: 1e-5)
    }

    func testTiltedTriangleArea() {
        // Triangle (0,0,0), (1,0,0), (0,1,1): area = ½·|(1,0,0)×(0,1,1)| = ½·√2.
        let pts: [SIMD3<Float>] = [.init(0, 0, 0), .init(1, 0, 0), .init(0, 1, 1)]
        XCTAssertEqual(MeasureMath.polygonArea(pts), 0.5 * 2.0.squareRoot(), accuracy: 1e-5)
    }

    func testPolygonAreaNeedsThreePoints() {
        XCTAssertEqual(MeasureMath.polygonArea([]), 0.0)
        XCTAssertEqual(MeasureMath.polygonArea([.init(0, 0, 0), .init(1, 0, 0)]), 0.0)
    }

    // MARK: - prismVolume

    func testPrismVolumeIsBaseAreaTimesHeight() {
        // 2×2 floor square (area 4), apex 2.5 m above the base plane → 10 m³.
        let base: [SIMD3<Float>] = [
            .init(0, 0, 0), .init(2, 0, 0), .init(2, 0, 2), .init(0, 0, 2),
        ]
        let apex = SIMD3<Float>(1, 2.5, 1)
        XCTAssertEqual(MeasureMath.prismVolume(base: base, apex: apex), 10.0, accuracy: 1e-4)
    }

    // MARK: - angleDegrees

    func testRightAngle() {
        let deg = MeasureMath.angleDegrees(a: .init(1, 0, 0), vertex: .init(0, 0, 0), c: .init(0, 1, 0))
        XCTAssertEqual(deg, 90.0, accuracy: 1e-4)
    }

    func testStraightLineIs180() {
        let deg = MeasureMath.angleDegrees(a: .init(-1, 0, 0), vertex: .init(0, 0, 0), c: .init(1, 0, 0))
        XCTAssertEqual(deg, 180.0, accuracy: 1e-4)
    }

    // MARK: - snap

    func testSnapWithinThresholdReturnsNearestExistingPoint() {
        let existing: [SIMD3<Float>] = [.init(0, 0, 0), .init(1, 0, 0)]
        let snapped = MeasureMath.snap(.init(0.01, 0, 0), to: existing, threshold: 0.02)
        XCTAssertEqual(snapped, SIMD3<Float>(0, 0, 0))
    }

    func testSnapOutsideThresholdReturnsNil() {
        let existing: [SIMD3<Float>] = [.init(0, 0, 0)]
        XCTAssertNil(MeasureMath.snap(.init(0.05, 0, 0), to: existing, threshold: 0.02))
    }

    // MARK: - result(mode:points:)

    func testDistanceResult() {
        let pts: [SIMD3<Float>] = [.init(0, 0, 0), .init(3, 4, 0), .init(3, 4, 12)]
        let r = MeasureMath.result(mode: .distance, points: pts)
        XCTAssertEqual(r.mode, .distance)
        XCTAssertEqual(r.segmentLengths.count, 2)
        XCTAssertEqual(r.segmentLengths[0], 5.0, accuracy: 1e-5)
        XCTAssertEqual(r.segmentLengths[1], 12.0, accuracy: 1e-5)
        XCTAssertEqual(r.totalLength, 17.0, accuracy: 1e-5)
        XCTAssertNil(r.area)
        XCTAssertNil(r.volume)
        XCTAssertNil(r.angleDegrees)
    }

    func testAreaResultClosesThePolygon() {
        let pts: [SIMD3<Float>] = [
            .init(0, 0, 0), .init(2, 0, 0), .init(2, 0, 2), .init(0, 0, 2),
        ]
        let r = MeasureMath.result(mode: .area, points: pts)
        XCTAssertEqual(r.area ?? -1, 4.0, accuracy: 1e-5)
        // Perimeter includes the closing segment: 2+2+2+2.
        XCTAssertEqual(r.totalLength, 8.0, accuracy: 1e-5)
        XCTAssertNil(r.volume)
    }

    func testVolumeResultUsesLastPointAsApex() {
        let pts: [SIMD3<Float>] = [
            .init(0, 0, 0), .init(2, 0, 0), .init(2, 0, 2), .init(0, 0, 2),
            .init(1, 2.5, 1), // apex
        ]
        let r = MeasureMath.result(mode: .volume, points: pts)
        XCTAssertEqual(r.area ?? -1, 4.0, accuracy: 1e-4)
        XCTAssertEqual(r.volume ?? -1, 10.0, accuracy: 1e-3)
    }

    func testAngleResultUsesFirstThreePoints() {
        let pts: [SIMD3<Float>] = [.init(1, 0, 0), .init(0, 0, 0), .init(0, 1, 0)]
        let r = MeasureMath.result(mode: .angle, points: pts)
        XCTAssertEqual(r.angleDegrees ?? -1, 90.0, accuracy: 1e-4)
    }

    func testResultWithTooFewPointsIsZeroed() {
        let r = MeasureMath.result(mode: .area, points: [.init(0, 0, 0)])
        XCTAssertEqual(r.totalLength, 0.0)
        XCTAssertNil(r.area)
        XCTAssertNil(r.angleDegrees)
    }

    // MARK: - Codable round-trips for the domain types

    func testWorldPointCodableRoundTrip() throws {
        let p = WorldPoint(position: .init(1.5, -2.25, 3.75))
        let decoded = try JSONDecoder().decode(WorldPoint.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded, p)
        XCTAssertEqual(decoded.position, p.position)
    }

    func testMeasureResultCodableRoundTrip() throws {
        let r = MeasureMath.result(
            mode: .area,
            points: [.init(0, 0, 0), .init(2, 0, 0), .init(2, 0, 2), .init(0, 0, 2)]
        )
        let decoded = try JSONDecoder().decode(MeasureResult.self, from: JSONEncoder().encode(r))
        XCTAssertEqual(decoded, r)
    }
}
