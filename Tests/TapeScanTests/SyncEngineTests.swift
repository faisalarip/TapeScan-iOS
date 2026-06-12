// SyncEngineTests.swift — offline-first merge contracts (M7).
//
// The engine syncs SwiftData against a SyncRemote seam, so every merge rule
// is pinned here with a MockSyncRemote + in-memory container:
// last-write-wins by updatedAt, tombstones propagate both directions and
// purge after applying, and lastPulledAt advances. SwiftData stays the
// source of truth — sync failures never mutate local state.

import XCTest
import SwiftData
@testable import TapeScan

@MainActor
final class SyncEngineTests: XCTestCase {

    private final class MockSyncRemote: SyncRemote, @unchecked Sendable {
        var pushed: [[SyncRecordPayload]] = []
        var pullResult: [SyncRecordPayload] = []
        var pullSince: Date??

        func push(_ records: [SyncRecordPayload]) async throws {
            pushed.append(records)
        }
        func pull(since: Date?) async throws -> [SyncRecordPayload] {
            pullSince = since
            return pullResult
        }
    }

    private var container: ModelContainer!
    private var remote: MockSyncRemote!
    private var engine: SyncEngine!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: SyncEngine.lastPulledAtKey)
        container = ModelContainerFactory.makeInMemory()
        remote = MockSyncRemote()
        engine = SyncEngine(remote: remote)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: SyncEngine.lastPulledAtKey)
        super.tearDown()
    }

    private func makeMeasurement(name: String = "Sofa") throws -> MeasurementRecord {
        let points = [WorldPoint(position: .init(0, 0, 0)), WorldPoint(position: .init(2, 0, 0))]
        return try MeasurementRecord(name: name, mode: .distance, points: points,
                                     result: MeasureMath.result(mode: .distance,
                                                                points: points.map(\.position)))
    }

    // MARK: - Push

    func testUnsyncedLocalRecordsPushAndMarkSynced() async throws {
        let context = container.mainContext
        let record = try makeMeasurement()
        context.insert(record)
        try context.save()

        try await engine.syncNow(context: context)

        XCTAssertEqual(remote.pushed.count, 1)
        XCTAssertEqual(remote.pushed[0].count, 1)
        XCTAssertEqual(remote.pushed[0][0].collection, "measurements")
        XCTAssertEqual(remote.pushed[0][0].id, record.id)
        XCTAssertEqual(record.remoteSyncedAt, record.updatedAt)
    }

    func testAlreadySyncedRecordsAreNotRepushed() async throws {
        let context = container.mainContext
        let record = try makeMeasurement()
        context.insert(record)
        try context.save()

        try await engine.syncNow(context: context)
        try await engine.syncNow(context: context)

        XCTAssertEqual(remote.pushed.count, 2)
        XCTAssertTrue(remote.pushed[1].isEmpty, "second sync has nothing new to push")
    }

    func testLocalTombstonePushesThenPurges() async throws {
        let context = container.mainContext
        let record = try makeMeasurement()
        context.insert(record)
        try context.save()
        try await engine.syncNow(context: context)

        record.markDeleted()
        try context.save()
        try await engine.syncNow(context: context)

        // The tombstone went out…
        XCTAssertNotNil(remote.pushed[1][0].deletedAt)
        // …and the local row is purged after the successful push.
        let remaining = try context.fetch(FetchDescriptor<MeasurementRecord>())
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - Pull

    func testPullInsertsUnknownRemoteRecord() async throws {
        let context = container.mainContext
        let incoming = try SyncDTO.measurementPayload(
            id: UUID(), name: "Remote door", mode: .distance,
            points: [WorldPoint(position: .init(0, 0, 0)), WorldPoint(position: .init(1, 0, 0))],
            updatedAt: Date(timeIntervalSince1970: 1_000), deletedAt: nil)
        remote.pullResult = [incoming]

        try await engine.syncNow(context: context)

        let records = try context.fetch(FetchDescriptor<MeasurementRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].name, "Remote door")
        XCTAssertEqual(records[0].remoteSyncedAt, records[0].updatedAt)
    }

    func testPullNewerRemoteWinsOverOlderLocal() async throws {
        let context = container.mainContext
        let record = try makeMeasurement(name: "Old name")
        context.insert(record)
        try context.save()
        try await engine.syncNow(context: context)   // synced baseline

        let newer = try SyncDTO.measurementPayload(
            id: record.id, name: "Renamed remotely", mode: .distance,
            points: try record.decodedPoints(),
            updatedAt: record.updatedAt.addingTimeInterval(60), deletedAt: nil)
        remote.pullResult = [newer]

        try await engine.syncNow(context: context)
        XCTAssertEqual(record.name, "Renamed remotely")
    }

    func testPullOlderRemoteLosesToNewerLocal() async throws {
        let context = container.mainContext
        let record = try makeMeasurement(name: "Local truth")
        context.insert(record)
        try context.save()

        let older = try SyncDTO.measurementPayload(
            id: record.id, name: "Stale remote", mode: .distance,
            points: try record.decodedPoints(),
            updatedAt: record.updatedAt.addingTimeInterval(-60), deletedAt: nil)
        remote.pullResult = [older]

        try await engine.syncNow(context: context)
        XCTAssertEqual(record.name, "Local truth")
    }

    func testRemoteTombstoneDeletesLocal() async throws {
        let context = container.mainContext
        let record = try makeMeasurement()
        context.insert(record)
        try context.save()
        try await engine.syncNow(context: context)

        let tombstone = try SyncDTO.measurementPayload(
            id: record.id, name: record.name, mode: .distance,
            points: [], updatedAt: record.updatedAt.addingTimeInterval(60),
            deletedAt: Date())
        remote.pullResult = [tombstone]

        try await engine.syncNow(context: context)
        let remaining = try context.fetch(FetchDescriptor<MeasurementRecord>())
        XCTAssertTrue(remaining.isEmpty)
    }

    func testLastPulledAtAdvancesToNewestIncoming() async throws {
        let context = container.mainContext
        let stamp = Date(timeIntervalSince1970: 2_000)
        remote.pullResult = [try SyncDTO.measurementPayload(
            id: UUID(), name: "X", mode: .distance,
            points: [], updatedAt: stamp, deletedAt: nil)]

        try await engine.syncNow(context: context)
        try await engine.syncNow(context: context)

        // Second pull uses the recorded watermark.
        XCTAssertEqual(remote.pullSince ?? nil, stamp)
    }
}
