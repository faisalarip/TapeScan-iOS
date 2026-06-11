// AppStateBrandTests.swift — brand single-source contract (M1).
//
// TapeScan ships with exactly one default-brand literal: AppState.defaultBrand.
// AppState.brand defaults to it; SettingsView's BrandField fallback and the
// onboarding eyebrow both derive from it. No other "TapeScan" brand literal
// may exist in Sources (enforced by the grep check in this task's plan).

import XCTest
@testable import TapeScan

final class AppStateBrandTests: XCTestCase {

    @MainActor
    func testDefaultBrandIsTapeScan() {
        XCTAssertEqual(AppState.defaultBrand, "TapeScan")
        XCTAssertEqual(AppState().brand, "TapeScan")
    }
}
