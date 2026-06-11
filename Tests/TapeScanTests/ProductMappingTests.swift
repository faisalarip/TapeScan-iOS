// ProductMappingTests.swift — StoreKit product → paywall plan mapping (M3).
//
// The mapping is pure so localized pricing, the savings tag, the
// substantiating compareAt anchor, and trial copy are all testable without
// StoreKit. Guardrails pinned here: the savings claim must be computed from
// real prices, and trial copy may only appear when an introductory offer
// actually exists (Guideline 3.1.2 accuracy).

import XCTest
@testable import TapeScan

final class ProductMappingTests: XCTestCase {

    private func usd(_ value: Decimal) -> String {
        "$" + String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func infos(monthlyIntro: Bool = true,
                       annualIntro: Bool = true) -> [ProductInfo] {
        [
            ProductInfo(id: ProductMapping.monthlyID, displayPrice: "$4.99",
                        price: 4.99, period: .month, hasIntroOffer: monthlyIntro),
            ProductInfo(id: ProductMapping.annualID, displayPrice: "$24.99",
                        price: 24.99, period: .year, hasIntroOffer: annualIntro),
            ProductInfo(id: ProductMapping.lifetimeID, displayPrice: "$59.99",
                        price: 59.99, period: nil, hasIntroOffer: false),
        ]
    }

    func testDisplayOrderAndNames() {
        let plans = ProductMapping.plans(from: infos().shuffled(), formatPrice: usd)
        XCTAssertEqual(plans.map(\.id),
                       [ProductMapping.monthlyID, ProductMapping.annualID, ProductMapping.lifetimeID])
        XCTAssertEqual(plans.map(\.displayName), ["Monthly", "Annual", "Lifetime"])
        XCTAssertEqual(ProductMapping.defaultSelectionID, ProductMapping.annualID)
    }

    func testAnnualSavingsComputedFromRealPrices() {
        let plans = ProductMapping.plans(from: infos(), formatPrice: usd)
        let annual = plans[1]
        // 12 × 4.99 = 59.88; savings = (59.88 − 24.99) / 59.88 = 58.27% → 58.
        XCTAssertEqual(annual.tag, "SAVE 58%")
        XCTAssertEqual(annual.compareAt, "$59.88")
        XCTAssertEqual(annual.subtitle, "$2.08 / mo · billed yearly")
    }

    func testNoSavingsTagWithoutMonthlyAnchor() {
        let onlyAnnual = [ProductInfo(id: ProductMapping.annualID, displayPrice: "$24.99",
                                      price: 24.99, period: .year, hasIntroOffer: true)]
        let plans = ProductMapping.plans(from: onlyAnnual, formatPrice: usd)
        XCTAssertEqual(plans.count, 1)
        XCTAssertNil(plans[0].tag)
        XCTAssertNil(plans[0].compareAt)
    }

    func testTrialOnlyWhenIntroOfferExists() {
        let with = ProductMapping.plans(from: infos(), formatPrice: usd)
        XCTAssertTrue(with[0].hasTrial)
        XCTAssertTrue(with[1].hasTrial)
        XCTAssertFalse(with[2].hasTrial, "lifetime never claims a trial")

        let without = ProductMapping.plans(from: infos(monthlyIntro: false, annualIntro: false),
                                           formatPrice: usd)
        XCTAssertFalse(without[0].hasTrial)
        XCTAssertFalse(without[1].hasTrial)
        XCTAssertEqual(without[0].ctaLabel, "Unlock Monthly · $4.99",
                       "no trial copy without a configured introductory offer")
    }

    func testTrialDisclosureShowsExactPostTrialPrice() {
        let plans = ProductMapping.plans(from: infos(), formatPrice: usd)
        XCTAssertEqual(plans[1].disclosure,
                       "Free for 7 days, then $24.99/year. Auto-renews until canceled. Cancel anytime in Settings.")
        XCTAssertEqual(plans[2].disclosure, "One-time purchase. No subscription.")
    }

    func testEmptyInputYieldsEmptyPlans() {
        XCTAssertTrue(ProductMapping.plans(from: [], formatPrice: usd).isEmpty)
    }
}
