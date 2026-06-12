// FloorPlanEditorModelTests.swift — post-scan plan editing ops (M10).
//
// The editor's geometry rules are pinned here: corner welding (moving a
// shared corner moves every touching wall endpoint AND coincident room
// polygon vertices), exact-length entry scaling about the wall start,
// opening placement clamping, undo/redo snapshots, and save-time
// normalization back to a (0,0) min corner.

import XCTest
@testable import TapeScan

@MainActor
final class FloorPlanEditorModelTests: XCTestCase {

    /// 4 m × 3 m rectangle with welded corners, one door, one room polygon.
    private func rectPlan() -> FloorPlanModel {
        let bottom = FloorPlanModel.Wall(startX: 0, startY: 0, endX: 4, endY: 0)
        let right = FloorPlanModel.Wall(startX: 4, startY: 0, endX: 4, endY: 3)
        let top = FloorPlanModel.Wall(startX: 4, startY: 3, endX: 0, endY: 3)
        let left = FloorPlanModel.Wall(startX: 0, startY: 3, endX: 0, endY: 0)
        let door = FloorPlanModel.Opening(kind: .door, wallID: bottom.id, offset: 1.0, width: 0.9)
        let room = FloorPlanModel.RoomArea(label: "ROOM 1",
                                           polygonX: [0, 4, 4, 0], polygonY: [0, 0, 3, 3],
                                           areaSquareMeters: 12)
        return FloorPlanModel(walls: [bottom, right, top, left],
                              openings: [door], rooms: [room],
                              widthMeters: 4, heightMeters: 3,
                              capturedAt: Date(timeIntervalSince1970: 0))
    }

    func testCornersAreWeldedAndDeduped() {
        let editor = FloorPlanEditorModel(plan: rectPlan())
        XCTAssertEqual(editor.corners.count, 4)
        // The (4,0) corner attaches the bottom wall's end and right wall's start.
        let corner = editor.corners.first { abs($0.x - 4) < 1e-6 && abs($0.y) < 1e-6 }
        XCTAssertEqual(corner?.attachments.count, 2)
    }

    func testMoveCornerMovesAllAttachedWallsAndRoomVertex() {
        let editor = FloorPlanEditorModel(plan: rectPlan())
        let corner = editor.corners.first { abs($0.x - 4) < 1e-6 && abs($0.y) < 1e-6 }!

        editor.moveCorner(id: corner.id, toX: 4.5, y: -0.2)

        let bottom = editor.plan.walls[0]
        let right = editor.plan.walls[1]
        XCTAssertEqual(bottom.endX, 4.5, accuracy: 1e-9)
        XCTAssertEqual(bottom.endY, -0.2, accuracy: 1e-9)
        XCTAssertEqual(right.startX, 4.5, accuracy: 1e-9)
        XCTAssertEqual(right.startY, -0.2, accuracy: 1e-9)
        // The coincident room polygon vertex (index 1) follows the weld.
        XCTAssertEqual(editor.plan.rooms[0].polygonX[1], 4.5, accuracy: 1e-9)
        XCTAssertEqual(editor.plan.rooms[0].polygonY[1], -0.2, accuracy: 1e-9)
        XCTAssertTrue(editor.hasChanges)
    }

    func testSetLengthScalesAboutStartAndDragsWeldedNeighbors() {
        let editor = FloorPlanEditorModel(plan: rectPlan())
        let bottomID = editor.plan.walls[0].id

        editor.setLength(of: bottomID, to: 5.0)

        let bottom = editor.plan.walls[0]
        XCTAssertEqual(bottom.lengthMeters, 5.0, accuracy: 1e-6)
        XCTAssertEqual(bottom.endX, 5.0, accuracy: 1e-6)
        // The welded right wall's start corner followed the moved endpoint.
        XCTAssertEqual(editor.plan.walls[1].startX, 5.0, accuracy: 1e-6)
    }

    func testAddOpeningCentersAndClamps() {
        let editor = FloorPlanEditorModel(plan: rectPlan())
        let rightID = editor.plan.walls[1].id

        editor.addOpening(kind: .window, on: rightID)

        let added = editor.plan.openings.last!
        XCTAssertEqual(added.kind, .window)
        XCTAssertEqual(added.width, 1.2, accuracy: 1e-9)
        // Centered on the 3 m wall: offset = (3 − 1.2) / 2.
        XCTAssertEqual(added.offset, 0.9, accuracy: 1e-6)
    }

    func testMoveOpeningClampsToWall() {
        let editor = FloorPlanEditorModel(plan: rectPlan())
        let door = editor.plan.openings[0]

        editor.moveOpening(id: door.id, offset: 99)
        XCTAssertEqual(editor.plan.openings[0].offset, 4.0 - 0.9, accuracy: 1e-6)

        editor.moveOpening(id: door.id, offset: -5)
        XCTAssertEqual(editor.plan.openings[0].offset, 0, accuracy: 1e-9)
    }

    func testRemoveOpeningAndRenameRoom() {
        let editor = FloorPlanEditorModel(plan: rectPlan())
        editor.removeOpening(id: editor.plan.openings[0].id)
        XCTAssertTrue(editor.plan.openings.isEmpty)

        editor.renameRoom(id: editor.plan.rooms[0].id, to: "Kitchen")
        XCTAssertEqual(editor.plan.rooms[0].label, "KITCHEN")
    }

    func testUndoRedoRoundTrip() {
        let editor = FloorPlanEditorModel(plan: rectPlan())
        let original = editor.plan
        let corner = editor.corners[0]

        editor.moveCorner(id: corner.id, toX: corner.x + 1, y: corner.y)
        XCTAssertTrue(editor.canUndo)
        editor.undo()
        XCTAssertEqual(editor.plan, original)
        XCTAssertTrue(editor.canRedo)
        editor.redo()
        XCTAssertNotEqual(editor.plan, original)
    }

    func testNormalizedPlanShiftsMinCornerToOriginAndRecomputesBounds() {
        let editor = FloorPlanEditorModel(plan: rectPlan())
        // Drag the (0,0) corner into negative space.
        let corner = editor.corners.first { abs($0.x) < 1e-6 && abs($0.y) < 1e-6 }!
        editor.moveCorner(id: corner.id, toX: -1.0, y: -0.5)

        let normalized = editor.normalizedPlan()
        let minX = normalized.walls.flatMap { [$0.startX, $0.endX] }.min()!
        let minY = normalized.walls.flatMap { [$0.startY, $0.endY] }.min()!
        XCTAssertEqual(minX, 0, accuracy: 1e-9)
        XCTAssertEqual(minY, 0, accuracy: 1e-9)
        XCTAssertEqual(normalized.widthMeters, 5.0, accuracy: 1e-6)   // 4 − (−1)
        XCTAssertEqual(normalized.heightMeters, 3.5, accuracy: 1e-6)  // 3 − (−0.5)
        // Room areas recompute from the edited polygons.
        XCTAssertEqual(normalized.rooms[0].areaSquareMeters,
                       normalized.rooms[0].polygonAreaSquareMeters, accuracy: 1e-9)
    }
}
