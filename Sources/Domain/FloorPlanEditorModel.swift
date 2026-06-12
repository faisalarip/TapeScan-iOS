// FloorPlanEditorModel.swift — post-scan parametric plan editing (M10).
//
// RoomPlan output is never perfect; this model turns every inaccuracy into a
// 30-second fix: drag welded corners, type exact wall lengths, add/move/
// remove doors and windows, rename rooms. Pure operations on FloorPlanModel
// with snapshot undo/redo — fully unit-tested; the editor screen is a thin
// gesture layer on top.

import Foundation
import Observation

@MainActor
@Observable
public final class FloorPlanEditorModel {

    /// Endpoints within this distance weld into one draggable corner (meters).
    public static let weldToleranceMeters = 0.015

    public private(set) var plan: FloorPlanModel
    private let original: FloorPlanModel
    private var undoStack: [FloorPlanModel] = []
    private var redoStack: [FloorPlanModel] = []

    public init(plan: FloorPlanModel) {
        self.plan = plan
        self.original = plan
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var hasChanges: Bool { plan != original }

    // MARK: - Corners (welded wall endpoints)

    public struct Corner: Identifiable, Equatable {
        /// One endpoint of one wall belonging to this corner.
        public struct Attachment: Equatable {
            public var wallID: UUID
            public var isStart: Bool
        }
        public let id: Int          // stable index into the corner grouping
        public var x: Double
        public var y: Double
        public var attachments: [Attachment]
    }

    /// Wall endpoints grouped by weld tolerance, in deterministic order.
    public var corners: [Corner] {
        var result: [Corner] = []
        for wall in plan.walls {
            for isStart in [true, false] {
                let x = isStart ? wall.startX : wall.endX
                let y = isStart ? wall.startY : wall.endY
                if let index = result.firstIndex(where: {
                    abs($0.x - x) <= Self.weldToleranceMeters &&
                    abs($0.y - y) <= Self.weldToleranceMeters
                }) {
                    result[index].attachments.append(.init(wallID: wall.id, isStart: isStart))
                } else {
                    result.append(Corner(id: result.count, x: x, y: y,
                                         attachments: [.init(wallID: wall.id, isStart: isStart)]))
                }
            }
        }
        return result
    }

    /// Moves a welded corner: every attached wall endpoint and any room
    /// polygon vertex coincident with the old position follow.
    public func moveCorner(id: Int, toX x: Double, y: Double) {
        guard let corner = corners.first(where: { $0.id == id }) else { return }
        snapshot()
        apply(corner: corner, toX: x, y: y)
    }

    /// Live-drag variant: same geometry, ONE undo snapshot per gesture
    /// (call `beginGesture()` once when the drag starts).
    public func dragCorner(id: Int, toX x: Double, y: Double) {
        guard let corner = corners.first(where: { $0.id == id }) else { return }
        apply(corner: corner, toX: x, y: y)
    }

    public func beginGesture() { snapshot() }

    private func apply(corner: Corner, toX x: Double, y: Double) {
        for attachment in corner.attachments {
            guard let index = plan.walls.firstIndex(where: { $0.id == attachment.wallID }) else { continue }
            if attachment.isStart {
                plan.walls[index].startX = x
                plan.walls[index].startY = y
            } else {
                plan.walls[index].endX = x
                plan.walls[index].endY = y
            }
        }
        // Weld coincident room polygon vertices.
        for roomIndex in plan.rooms.indices {
            let n = min(plan.rooms[roomIndex].polygonX.count, plan.rooms[roomIndex].polygonY.count)
            for vertex in 0..<n {
                if abs(plan.rooms[roomIndex].polygonX[vertex] - corner.x) <= Self.weldToleranceMeters,
                   abs(plan.rooms[roomIndex].polygonY[vertex] - corner.y) <= Self.weldToleranceMeters {
                    plan.rooms[roomIndex].polygonX[vertex] = x
                    plan.rooms[roomIndex].polygonY[vertex] = y
                }
            }
        }
    }

    // MARK: - Exact lengths

    /// Sets a wall's length by moving its END corner along the wall direction
    /// (welded neighbors follow, exactly like a manual corner drag).
    public func setLength(of wallID: UUID, to meters: Double) {
        guard meters > 0,
              let wall = plan.walls.first(where: { $0.id == wallID }),
              wall.lengthMeters > 0 else { return }
        let scale = meters / wall.lengthMeters
        let newEndX = wall.startX + (wall.endX - wall.startX) * scale
        let newEndY = wall.startY + (wall.endY - wall.startY) * scale
        guard let endCorner = corners.first(where: {
            $0.attachments.contains(.init(wallID: wallID, isStart: false))
        }) else { return }
        snapshot()
        apply(corner: endCorner, toX: newEndX, y: newEndY)
    }

    // MARK: - Openings

    /// Adds a centered door (0.9 m) or window (1.2 m), clamped to the wall.
    public func addOpening(kind: FloorPlanModel.OpeningKind, on wallID: UUID) {
        guard let wall = plan.walls.first(where: { $0.id == wallID }) else { return }
        let width = min(kind == .window ? 1.2 : 0.9, wall.lengthMeters)
        snapshot()
        plan.openings.append(FloorPlanModel.Opening(
            kind: kind, wallID: wallID,
            offset: max(0, (wall.lengthMeters - width) / 2),
            width: width))
    }

    public func removeOpening(id: UUID) {
        guard plan.openings.contains(where: { $0.id == id }) else { return }
        snapshot()
        plan.openings.removeAll { $0.id == id }
    }

    /// Slides an opening along its wall, clamped so it never overhangs.
    public func moveOpening(id: UUID, offset: Double) {
        guard let index = plan.openings.firstIndex(where: { $0.id == id }),
              let wall = plan.walls.first(where: { $0.id == plan.openings[index].wallID })
        else { return }
        snapshot()
        let maxOffset = max(0, wall.lengthMeters - plan.openings[index].width)
        plan.openings[index].offset = min(max(0, offset), maxOffset)
    }

    // MARK: - Rooms

    public func renameRoom(id: UUID, to name: String) {
        guard let index = plan.rooms.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        snapshot()
        plan.rooms[index].label = trimmed.uppercased()
    }

    // MARK: - Undo / redo

    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(plan)
        plan = previous
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(plan)
        plan = next
    }

    private func snapshot() {
        undoStack.append(plan)
        redoStack.removeAll()
    }

    // MARK: - Save

    /// The edited plan re-normalized for persistence: min corner back at
    /// (0,0), bounds recomputed, room display areas refreshed.
    public func normalizedPlan() -> FloorPlanModel {
        var result = plan
        let xs = result.walls.flatMap { [$0.startX, $0.endX] }
        let ys = result.walls.flatMap { [$0.startY, $0.endY] }
        guard let minX = xs.min(), let minY = ys.min(),
              let maxX = xs.max(), let maxY = ys.max() else { return result }

        for index in result.walls.indices {
            result.walls[index].startX -= minX
            result.walls[index].startY -= minY
            result.walls[index].endX -= minX
            result.walls[index].endY -= minY
        }
        for index in result.rooms.indices {
            result.rooms[index].polygonX = result.rooms[index].polygonX.map { $0 - minX }
            result.rooms[index].polygonY = result.rooms[index].polygonY.map { $0 - minY }
            result.rooms[index].areaSquareMeters = result.rooms[index].polygonAreaSquareMeters
        }
        result.widthMeters = maxX - minX
        result.heightMeters = maxY - minY
        return result
    }
}
