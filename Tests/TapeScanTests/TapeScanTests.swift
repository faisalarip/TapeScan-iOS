// TapeScanTests.swift — bootstrap unit-test target (M1).
//
// One trivial test proving the TapeScanTests bundle builds, links the TapeScan
// module via @testable import, and runs in the Simulator. Real domain tests
// (MeasureMath, UnitFormat, converters, sync merge) arrive with M2+.

import XCTest
@testable import TapeScan

final class TapeScanTests: XCTestCase {

    func testMeasureUnitProvidesBothSystems() {
        XCTAssertEqual(MeasureUnit.allCases.count, 2)
        XCTAssertEqual(MeasureUnit.metric.title, "Metric")
        XCTAssertEqual(MeasureUnit.imperial.title, "Imperial")
    }
}
