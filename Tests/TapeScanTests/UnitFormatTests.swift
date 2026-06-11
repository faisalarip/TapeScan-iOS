// UnitFormatTests.swift — display-formatting contracts (M2).
//
// US trades work in fractional inches; competitors' unit bugs (areas in mm²,
// units reverting) are recurring 1-star themes, so the formatter behavior is
// pinned exactly.

import XCTest
@testable import TapeScan

final class UnitFormatTests: XCTestCase {

    // MARK: - Existing decimal formats (regression pins)

    func testMetricLength() {
        XCTAssertEqual(UnitFormat.length(2.345, .metric), "2.35 m")
    }

    func testImperialWholeInchLength() {
        // 1 m = 39.3701 in → 3 ft 3 in.
        XCTAssertEqual(UnitFormat.length(1.0, .imperial), "3′ 3″")
    }

    func testMetricArea() {
        XCTAssertEqual(UnitFormat.area(4.0, .metric), "4.00 m²")
    }

    func testImperialArea() {
        XCTAssertEqual(UnitFormat.area(1.0, .imperial), "10.8 ft²")
    }

    // MARK: - Fractional imperial (competitive amendment)

    func testFractionalExactFeet() {
        // 12 ft exactly = 3.6576 m.
        XCTAssertEqual(UnitFormat.lengthFractional(3.6576, unit: .imperial), "12′")
    }

    func testFractionalFeetAndWholeInches() {
        // 12 ft 3 in = 3.7338 m.
        XCTAssertEqual(UnitFormat.lengthFractional(3.7338, unit: .imperial), "12′ 3″")
    }

    func testFractionalSixteenths() {
        // 12 ft 3 5/8 in = (147.625 in) × 0.0254 = 3.7496750 m.
        XCTAssertEqual(UnitFormat.lengthFractional(3.749675, unit: .imperial), "12′ 3 5/8″")
    }

    func testFractionReducesToLowestTerms() {
        // 8/16 reduces to 1/2: 0 ft 0 8/16 in = 0.0127 m.
        XCTAssertEqual(UnitFormat.lengthFractional(0.0127, unit: .imperial), "1/2″")
    }

    func testFractionalCarriesSixteenthsToNextInch() {
        // 15.97/16 in ≈ rounds to 16/16 → carries to 1 in: 0.02535 m ≈ 0.99803 in.
        XCTAssertEqual(UnitFormat.lengthFractional(0.02535, unit: .imperial), "1″")
    }

    func testFractionalCarriesInchesToNextFoot() {
        // 11.97 in = 0.304038 m → 191.52 sixteenths → rounds to 192 → 1 ft.
        XCTAssertEqual(UnitFormat.lengthFractional(0.304038, unit: .imperial), "1′")
    }

    func testFractionalZero() {
        XCTAssertEqual(UnitFormat.lengthFractional(0.0, unit: .imperial), "0″")
    }

    func testFractionalMetricFallsBackToDecimal() {
        // Metric callers get the standard decimal form from the same entry point.
        XCTAssertEqual(UnitFormat.lengthFractional(2.345, unit: .metric), "2.35 m")
    }
}
