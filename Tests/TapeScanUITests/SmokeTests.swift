// SmokeTests.swift — release smoke flows (M9).
//
// Rides the DEBUG-only -ui* launch arguments (AppState.bootstrapped) to land
// directly on each surface. Assertions favor resilience over pixel detail:
// the suite exists to catch crashes and missing chrome, not copy drift.

import XCTest

final class SmokeTests: XCTestCase {

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @MainActor
    func testAppLaunchesToMainTabs() throws {
        let app = launch(["-uiPhase", "main"])
        XCTAssertEqual(app.state, .runningForeground)
        // The custom tab bar's four tabs are reachable.
        XCTAssertTrue(app.buttons["Measure"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Settings"].exists)
    }

    @MainActor
    func testMeasureHUDShowsLiveChrome() throws {
        let app = launch(["-uiPhase", "main", "-uiTab", "measure"])
        // Mode chip (DISTANCE) and the telemetry strip's TRACK label render.
        XCTAssertTrue(app.staticTexts["DISTANCE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["TRACK"].exists)
    }

    @MainActor
    func testHistoryTabRenders() throws {
        let app = launch(["-uiPhase", "main", "-uiTab", "history"])
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 5))
        // Search field present (content varies with stored data — both the
        // empty state and a populated list are valid).
        XCTAssertTrue(app.textFields.firstMatch.exists)
    }

    @MainActor
    func testSettingsShowsPurchaseAndAboutRows() throws {
        let app = launch(["-uiPhase", "main", "-uiTab", "settings"])
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))

        // Rows are combined accessibility elements; match by label anywhere
        // in the tree and scroll until found.
        func row(_ label: String) -> XCUIElement {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", label))
                .firstMatch
        }
        let restore = row("Restore Purchases")
        for _ in 0..<4 where !restore.exists { app.swipeUp() }
        XCTAssertTrue(restore.waitForExistence(timeout: 3))

        let version = row("Version")
        for _ in 0..<3 where !version.exists { app.swipeUp() }
        XCTAssertTrue(version.waitForExistence(timeout: 3))
    }

    @MainActor
    func testPaywallPresentsAndCloses() throws {
        let app = launch(["-uiPhase", "main", "-uiPaywall", "proactive"])
        // Paywall chrome renders (plans come from TapeScan.storekit when the
        // config is attached; the loading/retry state is also crash-free).
        XCTAssertTrue(app.staticTexts["Unlock the full toolkit"].waitForExistence(timeout: 6))
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        close.tap()
        XCTAssertTrue(app.buttons["Measure"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRoomsTabShowsScanEntry() throws {
        let app = launch(["-uiPhase", "main", "-uiTab", "rooms"])
        XCTAssertTrue(app.staticTexts["Rooms"].waitForExistence(timeout: 5))
        // Simulator reports scan support, so the scan entry must exist.
        XCTAssertTrue(app.buttons["Start a new room scan"].exists)
    }
}
