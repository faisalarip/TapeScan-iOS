// FloorPlanModel.swift — parametric 2D floor plan (M2).
//
// The single geometry source for plan rendering, post-scan editing (M10),
// exports (PDF/PNG/SVG/DXF/glTF/CSV — M6), and sync payloads (M7). Derived
// from RoomPlan's CapturedRoom by CapturedRoomConverter (M5). All coordinates
// are PLAN SPACE in METERS, normalized so the minimum corner is (0,0) with
// +y pointing "down" the plan. Defined by the architecture contracts doc;
// change shapes there first.

import Foundation

public struct FloorPlanModel: Codable, Equatable, Sendable {

    public struct Wall: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public var startX: Double
        public var startY: Double
        public var endX: Double
        public var endY: Double
        /// Drawn wall thickness in meters (RoomPlan default ≈ 0.12).
        public var thickness: Double

        public init(id: UUID = UUID(),
                    startX: Double, startY: Double,
                    endX: Double, endY: Double,
                    thickness: Double = 0.12) {
            self.id = id
            self.startX = startX
            self.startY = startY
            self.endX = endX
            self.endY = endY
            self.thickness = thickness
        }

        public var lengthMeters: Double {
            ((endX - startX) * (endX - startX) + (endY - startY) * (endY - startY)).squareRoot()
        }
    }

    public enum OpeningKind: String, Codable, Sendable { case door, window, opening }

    public struct Opening: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public var kind: OpeningKind
        /// The wall this opening cuts through.
        public var wallID: UUID
        /// Distance along the wall from its start point (meters).
        public var offset: Double
        /// Opening width along the wall (meters).
        public var width: Double

        public init(id: UUID = UUID(), kind: OpeningKind, wallID: UUID,
                    offset: Double, width: Double) {
            self.id = id
            self.kind = kind
            self.wallID = wallID
            self.offset = offset
            self.width = width
        }

        /// Standard opening heights used for wall-area quantities (meters):
        /// doors 2.0, windows 1.2, raw openings 2.0.
        public var standardHeightMeters: Double {
            switch kind {
            case .door, .opening: return 2.0
            case .window: return 1.2
            }
        }
    }

    public struct RoomArea: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public var label: String
        /// Closed polygon vertices (paired arrays keep the type trivially
        /// Codable for sync payloads).
        public var polygonX: [Double]
        public var polygonY: [Double]
        /// Display area as captured (m²); quantities recompute from the polygon.
        public var areaSquareMeters: Double

        public init(id: UUID = UUID(), label: String,
                    polygonX: [Double], polygonY: [Double],
                    areaSquareMeters: Double) {
            self.id = id
            self.label = label
            self.polygonX = polygonX
            self.polygonY = polygonY
            self.areaSquareMeters = areaSquareMeters
        }

        /// Shoelace area of the room polygon (m²).
        public var polygonAreaSquareMeters: Double {
            let n = min(polygonX.count, polygonY.count)
            guard n >= 3 else { return 0 }
            var sum = 0.0
            for i in 0..<n {
                let j = (i + 1) % n
                sum += polygonX[i] * polygonY[j] - polygonX[j] * polygonY[i]
            }
            return abs(sum) / 2
        }
    }

    public var walls: [Wall]
    public var openings: [Opening]
    public var rooms: [RoomArea]
    /// Plan bounding box (meters).
    public var widthMeters: Double
    public var heightMeters: Double
    /// Wall height used for wall-area/volume quantities (RoomPlan measures
    /// it; 2.4 m is the fallback).
    public var wallHeightMeters: Double
    public var capturedAt: Date

    public init(walls: [Wall], openings: [Opening], rooms: [RoomArea],
                widthMeters: Double, heightMeters: Double,
                wallHeightMeters: Double = 2.4,
                capturedAt: Date) {
        self.walls = walls
        self.openings = openings
        self.rooms = rooms
        self.widthMeters = widthMeters
        self.heightMeters = heightMeters
        self.wallHeightMeters = wallHeightMeters
        self.capturedAt = capturedAt
    }

    // MARK: - Quantities (competitive amendment: auto-computed renovation math)

    /// The renovation numbers (paint/flooring/estimates) shown on the plan
    /// screen and printed on PDF/CSV exports.
    public struct Quantities: Codable, Equatable, Sendable {
        public var perimeterMeters: Double
        public var floorAreaSquareMeters: Double
        /// Gross wall area minus standard-height opening areas.
        public var wallAreaSquareMeters: Double
        public var volumeCubicMeters: Double
    }

    public var quantities: Quantities {
        let perimeter = walls.reduce(0) { $0 + $1.lengthMeters }
        let floorArea = rooms.reduce(0) { $0 + $1.polygonAreaSquareMeters }
        let openingArea = openings.reduce(0) { $0 + $1.width * $1.standardHeightMeters }
        let wallArea = max(0, perimeter * wallHeightMeters - openingArea)
        return Quantities(perimeterMeters: perimeter,
                          floorAreaSquareMeters: floorArea,
                          wallAreaSquareMeters: wallArea,
                          volumeCubicMeters: floorArea * wallHeightMeters)
    }
}

#if DEBUG
extension FloorPlanModel {
    /// The demo apartment used by previews, simulator scans, and exporter
    /// unit tests — an L-shaped 5.2 m × 4.4 m flat matching the design's
    /// original hardcoded plan.
    public static let sample: FloorPlanModel = {
        let bottom = Wall(startX: 0.0, startY: 0.0, endX: 4.0, endY: 0.0)
        let notchRight = Wall(startX: 4.0, startY: 0.0, endX: 4.0, endY: 1.6)
        let notchTop = Wall(startX: 4.0, startY: 1.6, endX: 5.2, endY: 1.6)
        let right = Wall(startX: 5.2, startY: 1.6, endX: 5.2, endY: 4.4)
        let top = Wall(startX: 5.2, startY: 4.4, endX: 0.0, endY: 4.4)
        let left = Wall(startX: 0.0, startY: 4.4, endX: 0.0, endY: 0.0)

        let door = Opening(kind: .door, wallID: bottom.id, offset: 1.4, width: 0.9)
        let window = Opening(kind: .window, wallID: right.id, offset: 0.9, width: 1.2)

        let living = RoomArea(label: "LIVING",
                              polygonX: [0.0, 4.0, 4.0, 0.0],
                              polygonY: [0.0, 0.0, 2.4, 2.4],
                              areaSquareMeters: 9.6)
        let bed = RoomArea(label: "BED",
                           polygonX: [0.0, 2.6, 2.6, 0.0],
                           polygonY: [2.4, 2.4, 4.4, 4.4],
                           areaSquareMeters: 5.2)
        let kitchen = RoomArea(label: "KITCHEN",
                               polygonX: [2.6, 5.2, 5.2, 2.6],
                               polygonY: [2.4, 2.4, 4.4, 4.4],
                               areaSquareMeters: 5.2)

        return FloorPlanModel(walls: [bottom, notchRight, notchTop, right, top, left],
                              openings: [door, window],
                              rooms: [living, bed, kitchen],
                              widthMeters: 5.2,
                              heightMeters: 4.4,
                              wallHeightMeters: 2.4,
                              capturedAt: Date(timeIntervalSince1970: 1_749_500_000))
    }()
}
#endif
