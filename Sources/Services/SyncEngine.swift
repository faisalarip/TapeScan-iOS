// SyncEngine.swift — offline-first sync over the SyncRemote seam (M7).
//
// SwiftData is the source of truth; the engine pushes locally-changed
// records, pulls remote changes since the last watermark, and merges with
// last-write-wins on updatedAt. Deletes travel as tombstones and purge after
// applying. The remote is a protocol so merge rules unit-test against a mock;
// SupabaseSyncRemote is the production implementation.
//
// Failures throw — callers surface a passive status line, never an alert,
// and never block local use (the "your data is never hostage" contract).

import Foundation
import SwiftData

// MARK: - Wire format

/// One record on the wire. `payload` is the encoded domain DTO; the envelope
/// fields drive merging without decoding.
public struct SyncRecordPayload: Codable, Equatable, Sendable {
    public var id: UUID
    public var collection: String           // "measurements" | "rooms"
    public var payload: Data
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: UUID, collection: String, payload: Data,
                updatedAt: Date, deletedAt: Date?) {
        self.id = id
        self.collection = collection
        self.payload = payload
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

public protocol SyncRemote: Sendable {
    /// Upsert the records remotely (empty arrays allowed).
    func push(_ records: [SyncRecordPayload]) async throws
    /// All remote records changed strictly after `since` (nil = everything).
    func pull(since: Date?) async throws -> [SyncRecordPayload]
}

// MARK: - DTOs

/// Codable bodies for the payload field. usdzFilename stays device-local.
public enum SyncDTO {
    public struct Measurement: Codable {
        public var name: String
        public var mode: MeasureMode
        public var points: [WorldPoint]
        public var result: MeasureResult
        public var createdAt: Date
    }

    public struct Room: Codable {
        public var name: String
        public var plan: FloorPlanModel
        public var createdAt: Date
    }

    /// Test/factory helper: a measurement wire record.
    public static func measurementPayload(id: UUID, name: String, mode: MeasureMode,
                                          points: [WorldPoint],
                                          updatedAt: Date, deletedAt: Date?) throws -> SyncRecordPayload {
        let body = Measurement(name: name, mode: mode, points: points,
                               result: MeasureMath.result(mode: mode, points: points.map(\.position)),
                               createdAt: updatedAt)
        return SyncRecordPayload(id: id, collection: "measurements",
                                 payload: try JSONEncoder().encode(body),
                                 updatedAt: updatedAt, deletedAt: deletedAt)
    }
}

// MARK: - Engine

@MainActor
public final class SyncEngine {

    public static let lastPulledAtKey = "lastPulledAt"

    private let remote: any SyncRemote

    public init(remote: any SyncRemote) {
        self.remote = remote
    }

    /// Sign-out / account-switch hygiene. Forgets the pull watermark and removes
    /// CLOUD-DERIVED rows (`remoteSyncedAt != nil`) so the previous account's
    /// synced data can't leak into — or be re-uploaded under — the NEXT account on
    /// a shared device. Rows that were only ever local (never synced) are the
    /// device's own work and are kept. A re-sign-in re-pulls the owner's data
    /// fresh (since = nil), so signing out still never costs the owner anything.
    public static func purgeLocalSyncState(context: ModelContext) {
        UserDefaults.standard.removeObject(forKey: lastPulledAtKey)
        let measurements = (try? context.fetch(FetchDescriptor<MeasurementRecord>())) ?? []
        for record in measurements where record.remoteSyncedAt != nil {
            context.delete(record)
        }
        let rooms = (try? context.fetch(FetchDescriptor<RoomRecord>())) ?? []
        for record in rooms where record.remoteSyncedAt != nil {
            context.delete(record)
        }
        try? context.save()
    }

    /// One full push + pull + merge cycle.
    public func syncNow(context: ModelContext) async throws {
        try await push(context: context)
        try await pull(context: context)
        try context.save()
    }

    // MARK: - Push

    private func push(context: ModelContext) async throws {
        let measurements = try context.fetch(FetchDescriptor<MeasurementRecord>())
        let rooms = try context.fetch(FetchDescriptor<RoomRecord>())

        var outgoing: [SyncRecordPayload] = []
        var pushedMeasurements: [MeasurementRecord] = []
        var pushedRooms: [RoomRecord] = []

        for record in measurements where needsPush(record.remoteSyncedAt, record.updatedAt) {
            let body = SyncDTO.Measurement(name: record.name,
                                           mode: record.mode,
                                           points: (try? record.decodedPoints()) ?? [],
                                           result: (try? record.decodedResult())
                                               ?? MeasureResult(mode: record.mode),
                                           createdAt: record.createdAt)
            outgoing.append(SyncRecordPayload(id: record.id, collection: "measurements",
                                              payload: try JSONEncoder().encode(body),
                                              updatedAt: record.updatedAt,
                                              deletedAt: record.deletedAt))
            pushedMeasurements.append(record)
        }
        for record in rooms where needsPush(record.remoteSyncedAt, record.updatedAt) {
            let body = SyncDTO.Room(name: record.name,
                                    plan: (try? record.decodedPlan())
                                        ?? FloorPlanModel(walls: [], openings: [], rooms: [],
                                                          widthMeters: 0, heightMeters: 0,
                                                          capturedAt: record.createdAt),
                                    createdAt: record.createdAt)
            outgoing.append(SyncRecordPayload(id: record.id, collection: "rooms",
                                              payload: try JSONEncoder().encode(body),
                                              updatedAt: record.updatedAt,
                                              deletedAt: record.deletedAt))
            pushedRooms.append(record)
        }

        try await remote.push(outgoing)

        // Mark synced; purge tombstones the remote has now seen.
        for record in pushedMeasurements {
            if record.deletedAt != nil { context.delete(record) }
            else { record.remoteSyncedAt = record.updatedAt }
        }
        for record in pushedRooms {
            if record.deletedAt != nil { context.delete(record) }
            else { record.remoteSyncedAt = record.updatedAt }
        }
    }

    private func needsPush(_ syncedAt: Date?, _ updatedAt: Date) -> Bool {
        guard let syncedAt else { return true }
        return updatedAt > syncedAt
    }

    // MARK: - Pull

    private func pull(context: ModelContext) async throws {
        let since = UserDefaults.standard.object(forKey: Self.lastPulledAtKey) as? Date
        let incoming = try await remote.pull(since: since)
        guard !incoming.isEmpty else { return }

        for wire in incoming {
            switch wire.collection {
            case "measurements": try merge(measurement: wire, context: context)
            case "rooms": try merge(room: wire, context: context)
            default: continue
            }
        }

        if let newest = incoming.map(\.updatedAt).max() {
            let previous = since ?? .distantPast
            UserDefaults.standard.set(max(newest, previous), forKey: Self.lastPulledAtKey)
        }
    }

    private func merge(measurement wire: SyncRecordPayload, context: ModelContext) throws {
        let id = wire.id
        let existing = try context.fetch(
            FetchDescriptor<MeasurementRecord>(predicate: #Predicate { $0.id == id })).first

        if let existing {
            guard wire.updatedAt > existing.updatedAt else { return }   // local wins
            if wire.deletedAt != nil {
                context.delete(existing)
                return
            }
            let body = try JSONDecoder().decode(SyncDTO.Measurement.self, from: wire.payload)
            existing.name = body.name
            existing.modeRaw = body.mode.rawValue
            existing.pointsData = try JSONEncoder().encode(body.points)
            existing.resultData = try JSONEncoder().encode(body.result)
            existing.updatedAt = wire.updatedAt
            existing.remoteSyncedAt = wire.updatedAt
        } else if wire.deletedAt == nil {
            let body = try JSONDecoder().decode(SyncDTO.Measurement.self, from: wire.payload)
            let record = try MeasurementRecord(id: wire.id, name: body.name, mode: body.mode,
                                               points: body.points, result: body.result,
                                               createdAt: body.createdAt)
            record.updatedAt = wire.updatedAt
            record.remoteSyncedAt = wire.updatedAt
            context.insert(record)
        }
    }

    private func merge(room wire: SyncRecordPayload, context: ModelContext) throws {
        let id = wire.id
        let existing = try context.fetch(
            FetchDescriptor<RoomRecord>(predicate: #Predicate { $0.id == id })).first

        if let existing {
            guard wire.updatedAt > existing.updatedAt else { return }
            if wire.deletedAt != nil {
                context.delete(existing)
                return
            }
            let body = try JSONDecoder().decode(SyncDTO.Room.self, from: wire.payload)
            existing.name = body.name
            try existing.updatePlan(body.plan, at: wire.updatedAt)
            existing.remoteSyncedAt = wire.updatedAt
        } else if wire.deletedAt == nil {
            let body = try JSONDecoder().decode(SyncDTO.Room.self, from: wire.payload)
            let record = try RoomRecord(id: wire.id, name: body.name, plan: body.plan,
                                        usdzFilename: nil, createdAt: body.createdAt)
            record.updatedAt = wire.updatedAt
            record.remoteSyncedAt = wire.updatedAt
            context.insert(record)
        }
    }
}
