// SmokeTests.swift — bootstrap XCUITest target (M1).
//
// One trivial launch test proving the TapeScanUITests bundle builds and can
// drive the app. Real smoke flows (onboarding, paywall, settings, history)
// arrive with M9, riding the existing DEBUG-only -ui* launch arguments
// handled by AppState.bootstrapped().

import XCTest

final class SmokeTests: XCTestCase {

    @MainActor
    func testAppLaunchesToMainTabs() throws {
        let app = XCUIApplication()
        // DEBUG-only launch arg (see AppState.bootstrapped): skip auth + onboarding.
        app.launchArguments = ["-uiPhase", "main"]
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }
}
