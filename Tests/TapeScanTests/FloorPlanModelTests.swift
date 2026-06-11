// FloorPlanModelTests.swift — parametric floor-plan model contracts (M2).
//
// The model is the single geometry source for rendering, editing, exports
// (PDF/SVG/DXF/glTF/CSV), and sync, so its Codable stability and quantity
// math are pinned here.

import XCTest
@testable import TapeScan

final class FloorPlanModelTests: XCTestCase {

    /// A minimal 4 m × 3 m rectangular room with one door and one window.
    private func rectangularRoom() -> FloorPlanModel {
        let w1 = FloorPlanModel.Wall(id: UUID(), startX: 0, startY: 0, endX: 4, endY: 0, thickness: 0.12)
        let w2 = FloorPlanModel.Wall(id: UUID(), startX: 4, startY: 0, endX: 4, endY: 3, thickness: 0.12)
        let w3 = FloorPlanModel.Wall(id: UUID(), startX: 4, startY: 3, endX: 0, endY: 3, thickness: 0.12)
        let w4 = FloorPlanModel.Wall(id: UUID(), startX: 0, startY: 3, endX: 0, endY: 0, thickness: 0.12)
        let door = FloorPlanModel.Opening(id: UUID(), kind: .door, wallID: w1.id, offset: 1.0, width: 0.9)
        let window = FloorPlanModel.Opening(id: UUID(), kind: .window, wallID: w2.id, offset: 1.0, width: 1.2)
        let room = FloorPlanModel.RoomArea(id: UUID(), label: "ROOM 1",
                                           polygonX: [0, 4, 4, 0], polygonY: [0, 0, 3, 3],
                                           areaSquareMeters: 12)
        return FloorPlanModel(walls: [w1, w2, w3, w4],
                              openings: [door, window],
                              rooms: [room],
                              widthMeters: 4, heightMeters: 3,
                              wallHeightMeters: 2.4,
                              capturedAt: Date(timeIntervalSince1970: 1_750_000_000))
    }

    func testCodableRoundTrip() throws {
        let model = rectangularRoom()
        let decoded = try JSONDecoder().decode(FloorPlanModel.self, from: JSONEncoder().encode(model))
        XCTAssertEqual(decoded, model)
    }

    func testQuantitiesForRectangularRoom() {
        let q = rectangularRoom().quantities
        // Perimeter: 2×(4+3) = 14 m.
        XCTAssertEqual(q.perimeterMeters, 14.0, accuracy: 1e-6)
        // Floor area from the room polygon: 12 m².
        XCTAssertEqual(q.floorAreaSquareMeters, 12.0, accuracy: 1e-6)
        // Wall area: 14 m × 2.4 m = 33.6 minus door 0.9×2.0=1.8 and window 1.2×1.2=1.44.
        XCTAssertEqual(q.wallAreaSquareMeters, 33.6 - 1.8 - 1.44, accuracy: 1e-4)
        // Volume: 12 m² × 2.4 m = 28.8 m³.
        XCTAssertEqual(q.volumeCubicMeters, 28.8, accuracy: 1e-4)
    }

    func testSampleFixtureIsSane() {
        let s = FloorPlanModel.sample
        XCTAssertGreaterThanOrEqual(s.walls.count, 4)
        XCTAssertFalse(s.rooms.isEmpty)
        XCTAssertGreaterThan(s.widthMeters, 0)
        XCTAssertGreaterThan(s.heightMeters, 0)
        XCTAssertGreaterThan(s.quantities.floorAreaSquareMeters, 0)
        // Every opening must reference an existing wall.
        let wallIDs = Set(s.walls.map(\.id))
        for opening in s.openings {
            XCTAssertTrue(wallIDs.contains(opening.wallID),
                          "opening \(opening.id) references missing wall")
        }
    }
}
