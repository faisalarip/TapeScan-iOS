// TrackingQualityMappingTests.swift — ARKit camera state → domain TrackingQuality.

import XCTest
import ARKit
@testable import TapeScan

final class TrackingQualityMappingTests: XCTestCase {

    func testNotAvailableMapsToNotAvailable() {
        XCTAssertEqual(TrackingQuality(ARCamera.TrackingState.notAvailable), .notAvailable)
    }

    func testNormalMapsToNormal() {
        XCTAssertEqual(TrackingQuality(ARCamera.TrackingState.normal), .normal)
    }

    func testLimitedInitializingMapsToInitializing() {
        XCTAssertEqual(TrackingQuality(ARCamera.TrackingState.limited(.initializing)), .initializing)
    }

    func testLimitedExcessiveMotionMapsToLimitedWithGuidance() {
        XCTAssertEqual(TrackingQuality(ARCamera.TrackingState.limited(.excessiveMotion)),
                       .limited(reason: "Move slower"))
    }

    func testLimitedInsufficientFeaturesMapsToLimitedWithGuidance() {
        XCTAssertEqual(TrackingQuality(ARCamera.TrackingState.limited(.insufficientFeatures)),
                       .limited(reason: "Aim at a textured surface"))
    }

    func testLimitedRelocalizingMapsToLimitedWithGuidance() {
        XCTAssertEqual(TrackingQuality(ARCamera.TrackingState.limited(.relocalizing)),
                       .limited(reason: "Relocalizing — return to a mapped area"))
    }
}
