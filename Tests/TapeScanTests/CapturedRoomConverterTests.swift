// CapturedRoomConverterTests.swift — RoomPlan capture → FloorPlanModel (M5).
//
// The converter is pure: it consumes ScannedRoomData (a RoomPlan-free
// intermediate of wall/opening transforms + dimensions) so the projection,
// normalization, opening-offset, and room-polygon math are all testable in
// the Simulator. RoomPlan's own CapturedRoom is adapted into ScannedRoomData
// by a thin untested shim inside RoomScanService.

import XCTest
import simd
@testable import TapeScan

final class CapturedRoomConverterTests: XCTestCase {

    /// A wall surface: local +x spans the wall, centered at (cx, cy, cz),
    /// rotated `yawDegrees` about the world y axis.
    private func surface(_ category: ScannedRoomData.Surface.Category,
                         center: SIMD3<Float>,
                         width: Float,
                         height: Float = 2.4,
                         yawDegrees: Float = 0) -> ScannedRoomData.Surface {
        let yaw = yawDegrees * .pi / 180
        var transform = matrix_identity_float4x4
        // Rotation about y: local x maps to (cos, 0, -sin) in world space.
        transform.columns.0 = SIMD4<Float>(cos(yaw), 0, -sin(yaw), 0)
        transform.columns.2 = SIMD4<Float>(sin(yaw), 0, cos(yaw), 0)
        transform.columns.3 = SIMD4<Float>(center.x, center.y, center.z, 1)
        return ScannedRoomData.Surface(transform: transform,
                                       width: width,
                                       height: height,
                                       category: category)
    }

    /// A 4 m × 3 m rectangular room offset from the origin (tests normalization):
    /// plan-space walls at x ∈ [10, 14], z ∈ [5, 8].
    private func rectangularRoom(withDoor: Bool = true) -> ScannedRoomData {
        var surfaces: [ScannedRoomData.Surface] = [
            surface(.wall, center: .init(12, 1.2, 5), width: 4),                    // bottom (z=5)
            surface(.wall, center: .init(14, 1.2, 6.5), width: 3, yawDegrees: 90),  // right (x=14)
            surface(.wall, center: .init(12, 1.2, 8), width: 4),                    // top (z=8)
            surface(.wall, center: .init(10, 1.2, 6.5), width: 3, yawDegrees: 90),  // left (x=10)
        ]
        if withDoor {
            // Door on the bottom wall: center 1.45 m from the wall's min-x end.
            surfaces.append(surface(.door, center: .init(11.45, 1.0, 5), width: 0.9, height: 2.0))
        }
        return ScannedRoomData(surfaces: surfaces, floorPolygonXZ: nil)
    }

    func testWallsProjectAndNormalizeToOrigin() {
        let model = CapturedRoomConverter.convert(rectangularRoom(withDoor: false),
                                                  capturedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(model.walls.count, 4)
        XCTAssertEqual(model.widthMeters, 4.0, accuracy: 1e-4)
        XCTAssertEqual(model.heightMeters, 3.0, accuracy: 1e-4)

        // Every wall endpoint sits inside the normalized bounding box.
        for wall in model.walls {
            for v in [wall.startX, wall.endX] {
                XCTAssertGreaterThanOrEqual(v, -1e-4); XCTAssertLessThanOrEqual(v, 4.0 + 1e-4)
            }
            for v in [wall.startY, wall.endY] {
                XCTAssertGreaterThanOrEqual(v, -1e-4); XCTAssertLessThanOrEqual(v, 3.0 + 1e-4)
            }
        }
        // The min corner is exactly (0, 0).
        let minX = model.walls.flatMap { [$0.startX, $0.endX] }.min() ?? -1
        let minY = model.walls.flatMap { [$0.startY, $0.endY] }.min() ?? -1
        XCTAssertEqual(minX, 0, accuracy: 1e-4)
        XCTAssertEqual(minY, 0, accuracy: 1e-4)
    }

    func testWallHeightAveragesIntoModel() {
        let model = CapturedRoomConverter.convert(rectangularRoom(), capturedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(model.wallHeightMeters, 2.4, accuracy: 1e-4)
    }

    func testDoorAssociatesToNearestWallWithLeadingEdgeOffset() {
        let model = CapturedRoomConverter.convert(rectangularRoom(), capturedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(model.openings.count, 1)
        let door = model.openings[0]
        XCTAssertEqual(door.kind, .door)
        XCTAssertEqual(door.width, 0.9, accuracy: 1e-4)

        // It must reference the bottom wall (the one whose endpoints both lie
        // on the normalized z=0 edge).
        let host = model.walls.first { $0.id == door.wallID }
        XCTAssertNotNil(host)
        XCTAssertEqual(host?.startY ?? -1, 0, accuracy: 1e-3)
        XCTAssertEqual(host?.endY ?? -1, 0, accuracy: 1e-3)

        // Door center was 1.45 m from the wall's min end → leading edge at 1.0 m.
        XCTAssertEqual(door.offset, 1.0, accuracy: 1e-3)
    }

    func testFloorPolygonWinsOverConvexHull() {
        var data = rectangularRoom(withDoor: false)
        // An L-shaped floor polygon (in the same offset world space).
        data.floorPolygonXZ = [
            .init(10, 5), .init(13, 5), .init(13, 6.5), .init(14, 6.5),
            .init(14, 8), .init(10, 8),
        ]
        let model = CapturedRoomConverter.convert(data, capturedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(model.rooms.count, 1)
        // L-area: full 4×3 minus the 1×1.5 notch = 12 − 1.5 = 10.5.
        XCTAssertEqual(model.rooms[0].polygonAreaSquareMeters, 10.5, accuracy: 1e-3)
        XCTAssertEqual(model.quantities.floorAreaSquareMeters, 10.5, accuracy: 1e-3)
    }

    func testConvexHullFallbackForRectangle() {
        let model = CapturedRoomConverter.convert(rectangularRoom(withDoor: false),
                                                  capturedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(model.rooms.count, 1)
        XCTAssertEqual(model.rooms[0].polygonAreaSquareMeters, 12.0, accuracy: 1e-3)
    }

    func testEmptyCaptureYieldsEmptyModel() {
        let model = CapturedRoomConverter.convert(ScannedRoomData(surfaces: [], floorPolygonXZ: nil),
                                                  capturedAt: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(model.walls.isEmpty)
        XCTAssertTrue(model.rooms.isEmpty)
        XCTAssertEqual(model.widthMeters, 0)
    }
}
