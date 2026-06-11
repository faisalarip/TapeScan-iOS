// PersistenceTests.swift — SwiftData records + session-draft autosave (M2).
//
// Records carry sync bookkeeping (updatedAt / deletedAt tombstones /
// remoteSyncedAt) that M7's merge logic depends on, so the shapes are pinned
// here against an in-memory container. SessionDraftStore is the
// crash-recovery story: every competitor loses in-progress work to crashes.

import XCTest
import SwiftData
@testable import TapeScan

final class PersistenceTests: XCTestCase {

    // MARK: - MeasurementRecord

    @MainActor
    func testMeasurementRecordInsertAndQuery() throws {
        let container = ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let points = [WorldPoint(position: .init(0, 0, 0)),
                      WorldPoint(position: .init(3, 4, 0))]
        let result = MeasureMath.result(mode: .distance, points: points.map(\.position))
        let record = try MeasurementRecord(name: "Sofa width",
                                           mode: .distance,
                                           points: points,
                                           result: result)
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MeasurementRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].name, "Sofa width")
        XCTAssertEqual(fetched[0].mode, .distance)
        XCTAssertEqual(try fetched[0].decodedPoints(), points)
        XCTAssertEqual(try fetched[0].decodedResult().totalLength, 5.0, accuracy: 1e-5)
        XCTAssertNil(fetched[0].deletedAt)
        XCTAssertNil(fetched[0].remoteSyncedAt)
    }

    @MainActor
    func testMeasurementTombstoneDelete() throws {
        let container = ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let record = try MeasurementRecord(name: "Doorway",
                                           mode: .distance,
                                           points: [],
                                           result: MeasureResult(mode: .distance))
        context.insert(record)
        try context.save()

        record.markDeleted()
        try context.save()

        let all = try context.fetch(FetchDescriptor<MeasurementRecord>())
        XCTAssertEqual(all.count, 1, "tombstoned records stay until sync purges them")
        XCTAssertNotNil(all[0].deletedAt)
        XCTAssertGreaterThanOrEqual(all[0].updatedAt, all[0].createdAt)

        let visible = try context.fetch(MeasurementRecord.visibleDescriptor())
        XCTAssertTrue(visible.isEmpty, "visible query excludes tombstones")
    }

    // MARK: - RoomRecord

    @MainActor
    func testRoomRecordStoresPlan() throws {
        let container = ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let record = try RoomRecord(name: "Living room", plan: .sample, usdzFilename: nil)
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RoomRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(try fetched[0].decodedPlan(), FloorPlanModel.sample)
        XCTAssertEqual(fetched[0].areaSquareMeters,
                       FloorPlanModel.sample.quantities.floorAreaSquareMeters,
                       accuracy: 1e-6)
    }

    // MARK: - SessionDraftStore (crash recovery)

    func testDraftSaveLoadClear() {
        defer { SessionDraftStore.clear() }
        let draft = MeasureSessionDraft(
            mode: .area,
            points: [WorldPoint(position: .init(0, 0, 0)),
                     WorldPoint(position: .init(1, 0, 0))],
            savedAt: Date()
        )
        SessionDraftStore.save(draft)
        let loaded = SessionDraftStore.load()
        XCTAssertEqual(loaded?.mode, .area)
        XCTAssertEqual(loaded?.points, draft.points)

        SessionDraftStore.clear()
        XCTAssertNil(SessionDraftStore.load())
    }

    func testDraftLoadReturnsNilWhenNothingSaved() {
        SessionDraftStore.clear()
        XCTAssertNil(SessionDraftStore.load())
    }
}
