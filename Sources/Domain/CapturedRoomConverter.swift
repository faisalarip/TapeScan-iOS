// CapturedRoomConverter.swift — RoomPlan capture → parametric FloorPlanModel (M5).
//
// Pure geometry: consumes ScannedRoomData, a RoomPlan-free intermediate of
// surface transforms + dimensions (the thin extraction shim lives in
// RoomScanService). Plan space is the world XZ plane (y is up in ARKit/
// RoomPlan), normalized so the minimum corner is (0,0).

import Foundation
import simd

/// RoomPlan-free description of a captured room. `Surface.transform` is the
/// surface's world transform; local +x spans the surface width.
public struct ScannedRoomData: Equatable {
    public struct Surface: Equatable {
        public var transform: simd_float4x4
        public var width: Float
        public var height: Float
        public enum Category: Equatable { case wall, door, window, opening }
        public var category: Category

        public init(transform: simd_float4x4, width: Float, height: Float,
                    category: Category) {
            self.transform = transform
            self.width = width
            self.height = height
            self.category = category
        }
    }

    public var surfaces: [Surface]
    /// The floor's polygon corners in world XZ (iOS 17 RoomPlan provides
    /// them); nil falls back to the convex hull of wall endpoints.
    public var floorPolygonXZ: [SIMD2<Float>]?

    public init(surfaces: [Surface], floorPolygonXZ: [SIMD2<Float>]?) {
        self.surfaces = surfaces
        self.floorPolygonXZ = floorPolygonXZ
    }
}

public enum CapturedRoomConverter {

    public static func convert(_ data: ScannedRoomData, capturedAt: Date) -> FloorPlanModel {
        let wallSurfaces = data.surfaces.filter { $0.category == .wall }
        let openingSurfaces = data.surfaces.filter { $0.category != .wall }

        // Project each wall to a 2D segment in world XZ.
        struct RawWall { let start: SIMD2<Float>; let end: SIMD2<Float>; let height: Float }
        let rawWalls: [RawWall] = wallSurfaces.map { s in
            let center = SIMD2<Float>(s.transform.columns.3.x, s.transform.columns.3.z)
            let half = planDirection(of: s) * (s.width / 2)
            return RawWall(start: center - half, end: center + half, height: s.height)
        }

        guard !rawWalls.isEmpty else {
            return FloorPlanModel(walls: [], openings: [], rooms: [],
                                  widthMeters: 0, heightMeters: 0,
                                  wallHeightMeters: 2.4, capturedAt: capturedAt)
        }

        // Normalization: translate so the minimum corner is (0,0).
        let allPoints = rawWalls.flatMap { [$0.start, $0.end] }
        let minX = allPoints.map(\.x).min() ?? 0
        let minZ = allPoints.map(\.y).min() ?? 0
        let origin = SIMD2<Float>(minX, minZ)
        func planPoint(_ p: SIMD2<Float>) -> SIMD2<Float> { p - origin }

        let walls: [FloorPlanModel.Wall] = rawWalls.map { raw in
            let s = planPoint(raw.start), e = planPoint(raw.end)
            return FloorPlanModel.Wall(startX: Double(s.x), startY: Double(s.y),
                                       endX: Double(e.x), endY: Double(e.y))
        }

        // Openings: associate to the nearest wall; offset = distance along the
        // wall from its start to the opening's LEADING edge (center − width/2).
        var openings: [FloorPlanModel.Opening] = []
        for surface in openingSurfaces {
            let center = planPoint(SIMD2<Float>(surface.transform.columns.3.x,
                                                surface.transform.columns.3.z))
            guard let (index, along) = nearestWall(to: center, walls: walls) else { continue }
            let kind: FloorPlanModel.OpeningKind = switch surface.category {
            case .door: .door
            case .window: .window
            default: .opening
            }
            openings.append(FloorPlanModel.Opening(
                kind: kind,
                wallID: walls[index].id,
                offset: max(0, along - Double(surface.width) / 2),
                width: Double(surface.width)))
        }

        // Room polygon: the floor polygon when RoomPlan provides it, else the
        // convex hull of wall endpoints (overestimates concave rooms — the
        // M10 plan editor is the user remedy until multi-polygon support).
        let polygon: [SIMD2<Float>]
        if let floor = data.floorPolygonXZ, floor.count >= 3 {
            polygon = floor.map(planPoint)
        } else {
            polygon = convexHull(allPoints.map(planPoint))
        }
        var rooms: [FloorPlanModel.RoomArea] = []
        if polygon.count >= 3 {
            let room = FloorPlanModel.RoomArea(
                label: "ROOM",
                polygonX: polygon.map { Double($0.x) },
                polygonY: polygon.map { Double($0.y) },
                areaSquareMeters: 0)
            rooms = [FloorPlanModel.RoomArea(
                id: room.id, label: room.label,
                polygonX: room.polygonX, polygonY: room.polygonY,
                areaSquareMeters: room.polygonAreaSquareMeters)]
        }

        let maxX = allPoints.map(\.x).max() ?? 0
        let maxZ = allPoints.map(\.y).max() ?? 0
        let avgHeight = rawWalls.map { Double($0.height) }.reduce(0, +) / Double(rawWalls.count)

        return FloorPlanModel(walls: walls,
                              openings: openings,
                              rooms: rooms,
                              widthMeters: Double(maxX - minX),
                              heightMeters: Double(maxZ - minZ),
                              wallHeightMeters: avgHeight,
                              capturedAt: capturedAt)
    }

    // MARK: - Geometry helpers

    /// The surface's width direction projected onto the XZ plane, normalized.
    private static func planDirection(of surface: ScannedRoomData.Surface) -> SIMD2<Float> {
        let localX = surface.transform.columns.0
        let dir = SIMD2<Float>(localX.x, localX.z)
        let length = simd_length(dir)
        return length > 0 ? dir / length : SIMD2<Float>(1, 0)
    }

    /// Index of the wall nearest to `point` plus the clamped distance along
    /// that wall from its start to the point's projection.
    private static func nearestWall(to point: SIMD2<Float>,
                                    walls: [FloorPlanModel.Wall]) -> (index: Int, along: Double)? {
        var best: (index: Int, along: Double, distance: Float)?
        for (index, wall) in walls.enumerated() {
            let a = SIMD2<Float>(Float(wall.startX), Float(wall.startY))
            let b = SIMD2<Float>(Float(wall.endX), Float(wall.endY))
            let ab = b - a
            let lengthSq = simd_length_squared(ab)
            guard lengthSq > 0 else { continue }
            let t = max(0, min(1, dot(point - a, ab) / lengthSq))
            let closest = a + ab * t
            let distance = simd_distance(point, closest)
            if distance < (best?.distance ?? .greatestFiniteMagnitude) {
                best = (index, Double(t) * Double(simd_length(ab)), distance)
            }
        }
        guard let best else { return nil }
        return (best.index, best.along)
    }

    /// Andrew's monotone-chain convex hull.
    private static func convexHull(_ points: [SIMD2<Float>]) -> [SIMD2<Float>] {
        let unique: Set<Wrapped> = Set(points.map { Wrapped(p: $0) })
        var sorted: [SIMD2<Float>] = unique.map(\.p)
        sorted.sort { a, b in
            if a.x == b.x { return a.y < b.y }
            return a.x < b.x
        }
        guard sorted.count >= 3 else { return sorted }

        func cross(_ o: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }

        var lower: [SIMD2<Float>] = []
        for p in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }
        var upper: [SIMD2<Float>] = []
        for p in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }

    /// Hashable wrapper so duplicate endpoints collapse before hulling.
    private struct Wrapped: Hashable {
        let p: SIMD2<Float>
        static func == (l: Wrapped, r: Wrapped) -> Bool { l.p == r.p }
        func hash(into hasher: inout Hasher) {
            hasher.combine(p.x); hasher.combine(p.y)
        }
    }
}
