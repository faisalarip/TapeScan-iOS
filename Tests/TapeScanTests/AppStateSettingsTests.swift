// AppStateSettingsTests.swift — settings persistence contract (M2).
//
// User preferences (unit, accent, density, snapping, onboarding completion,
// export quota) must survive relaunch — the audit's "everything resets every
// launch" blocker. isPro is deliberately NOT covered here: it derives from
// StoreKit entitlements (M3), never from a stored flag.

import XCTest
@testable import TapeScan

final class AppStateSettingsTests: XCTestCase {

    private let keys = ["unit", "accent", "density", "hasOnboarded",
                        "freeExportsLeft", "snapEnabled"]

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    @MainActor
    func testDefaultsWhenNothingPersisted() {
        let s = AppState()
        XCTAssertEqual(s.unit, .metric)
        XCTAssertEqual(s.accent, .blue)
        XCTAssertEqual(s.density, .regular)
        XCTAssertTrue(s.snapEnabled)
        XCTAssertFalse(s.hasOnboarded)
        XCTAssertEqual(s.freeExportsLeft, 3)
    }

    @MainActor
    func testSettingsPersistAcrossInstances() {
        let first = AppState()
        first.unit = .imperial
        first.accent = .green
        first.density = .comfy
        first.snapEnabled = false
        first.freeExportsLeft = 1
        first.completeOnboarding()

        let second = AppState()
        XCTAssertEqual(second.unit, .imperial)
        XCTAssertEqual(second.accent, .green)
        XCTAssertEqual(second.density, .comfy)
        XCTAssertFalse(second.snapEnabled)
        XCTAssertEqual(second.freeExportsLeft, 1)
        XCTAssertTrue(second.hasOnboarded)
    }

    @MainActor
    func testIsProIsNeverPersistedByAppState() {
        let first = AppState()
        first.isPro = true
        let second = AppState()
        XCTAssertFalse(second.isPro, "isPro must derive from StoreKit entitlements, not storage")
    }

    @MainActor
    func testAlertPresentation() {
        let s = AppState()
        XCTAssertNil(s.alert)
        s.presentAlert(title: "Export failed", message: "Could not write the PDF.")
        XCTAssertEqual(s.alert?.title, "Export failed")
        XCTAssertEqual(s.alert?.message, "Could not write the PDF.")
    }
}
