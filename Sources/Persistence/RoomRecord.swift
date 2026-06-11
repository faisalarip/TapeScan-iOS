// RoomRecord.swift — persisted room scan (M2).
//
// Stores the parametric FloorPlanModel as JSON plus an optional reference to
// the RoomPlan USDZ export on disk (Application Support/Rooms/<uuid>.usdz).
// Same sync bookkeeping contract as MeasurementRecord.

import Foundation
import SwiftData

@Model
public final class RoomRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var planData: Data
    /// Filename (not path) of the USDZ export under Application Support/Rooms;
    /// nil when the 3D capture isn't available (e.g. synced from another device).
    public var usdzFilename: String?
    public var areaSquareMeters: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var remoteSyncedAt: Date?

    public init(id: UUID = UUID(),
                name: String,
                plan: FloorPlanModel,
                usdzFilename: String?,
                createdAt: Date = Date()) throws {
        self.id = id
        self.name = name
        self.planData = try JSONEncoder().encode(plan)
        self.usdzFilename = usdzFilename
        self.areaSquareMeters = plan.quantities.floorAreaSquareMeters
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.deletedAt = nil
        self.remoteSyncedAt = nil
    }

    public func decodedPlan() throws -> FloorPlanModel {
        try JSONDecoder().decode(FloorPlanModel.self, from: planData)
    }

    /// Re-encode an edited plan (M10 editor) and bump the sync clock.
    public func updatePlan(_ plan: FloorPlanModel, at date: Date = Date()) throws {
        planData = try JSONEncoder().encode(plan)
        areaSquareMeters = plan.quantities.floorAreaSquareMeters
        updatedAt = date
    }

    public func markDeleted(at date: Date = Date()) {
        deletedAt = date
        updatedAt = date
    }

    public static func visibleDescriptor() -> FetchDescriptor<RoomRecord> {
        FetchDescriptor<RoomRecord>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }
}
