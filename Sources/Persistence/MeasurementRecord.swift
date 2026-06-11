// MeasurementRecord.swift — persisted measurement (M2).
//
// SwiftData model with sync bookkeeping: `updatedAt` drives last-write-wins
// merges, `deletedAt` is a tombstone (rows stay until sync propagates the
// delete), `remoteSyncedAt` tracks the last successful push (M7). Domain
// payloads are stored as JSON `Data` so the schema stays stable while the
// domain types evolve with Codable.

import Foundation
import SwiftData

@Model
public final class MeasurementRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var modeRaw: String
    public var pointsData: Data
    public var resultData: Data
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var remoteSyncedAt: Date?

    public init(id: UUID = UUID(),
                name: String,
                mode: MeasureMode,
                points: [WorldPoint],
                result: MeasureResult,
                createdAt: Date = Date()) throws {
        self.id = id
        self.name = name
        self.modeRaw = mode.rawValue
        self.pointsData = try JSONEncoder().encode(points)
        self.resultData = try JSONEncoder().encode(result)
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.deletedAt = nil
        self.remoteSyncedAt = nil
    }

    public var mode: MeasureMode { MeasureMode(rawValue: modeRaw) ?? .distance }

    public func decodedPoints() throws -> [WorldPoint] {
        try JSONDecoder().decode([WorldPoint].self, from: pointsData)
    }

    public func decodedResult() throws -> MeasureResult {
        try JSONDecoder().decode(MeasureResult.self, from: resultData)
    }

    /// Tombstone the record for sync; History queries exclude it immediately.
    public func markDeleted(at date: Date = Date()) {
        deletedAt = date
        updatedAt = date
    }

    /// Fetch descriptor for live (non-tombstoned) records, newest first.
    public static func visibleDescriptor() -> FetchDescriptor<MeasurementRecord> {
        FetchDescriptor<MeasurementRecord>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }
}
