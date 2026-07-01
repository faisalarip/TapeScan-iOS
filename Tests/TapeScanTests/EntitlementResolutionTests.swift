// EntitlementResolutionTests.swift — the transaction-listener entitlement rule.
//
// Regression coverage for the "Pro card only sticks on the SECOND subscribe"
// bug: the Transaction.updates listener used to write `isPro` straight from
// `Transaction.currentEntitlements`, which lags briefly right after a purchase
// (StoreKit-testing / Sandbox). A just-verified purchase would set isPro = true,
// then the listener's stale snapshot clobbered it back to false. The fix routes
// the "does THIS transaction prove Pro right now?" decision through the pure
// `transactionGrantsProNow`, which the listener ORs into the (possibly-lagging)
// recompute so a fresh grant can never be downgraded.

import XCTest
@testable import TapeScan

final class EntitlementResolutionTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    // A freshly-received monthly/annual sub whose expiry is in the future proves
    // a current entitlement on its own — this is the value the buggy version
    // failed to honor when currentEntitlements hadn't caught up yet.
    func testActiveSubscriptionGrantsProNow() {
        XCTAssertTrue(StoreKitPurchaseService.transactionGrantsProNow(
            productID: ProductMapping.monthlyID,
            isRevoked: false,
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 30),
            now: now))
        XCTAssertTrue(StoreKitPurchaseService.transactionGrantsProNow(
            productID: ProductMapping.annualID,
            isRevoked: false,
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 365),
            now: now))
    }

    // Lifetime is a non-consumable: no expiry (nil) == never expires == Pro.
    func testLifetimeWithNoExpiryGrantsPro() {
        XCTAssertTrue(StoreKitPurchaseService.transactionGrantsProNow(
            productID: ProductMapping.lifetimeID,
            isRevoked: false,
            expirationDate: nil,
            now: now))
    }

    // A refund/revocation must NOT force Pro on — it falls through to the
    // authoritative recompute (which correctly excludes revoked transactions).
    func testRevokedTransactionDoesNotGrantPro() {
        XCTAssertFalse(StoreKitPurchaseService.transactionGrantsProNow(
            productID: ProductMapping.monthlyID,
            isRevoked: true,
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 30),
            now: now))
    }

    // An expired subscription redelivered on catch-up must not resurrect Pro.
    func testExpiredSubscriptionDoesNotGrantPro() {
        XCTAssertFalse(StoreKitPurchaseService.transactionGrantsProNow(
            productID: ProductMapping.annualID,
            isRevoked: false,
            expirationDate: now.addingTimeInterval(-60),
            now: now))
    }

    // A transaction for some other product (not one of ours) never grants Pro.
    func testUnknownProductDoesNotGrantPro() {
        XCTAssertFalse(StoreKitPurchaseService.transactionGrantsProNow(
            productID: "com.example.some.other.product",
            isRevoked: false,
            expirationDate: nil,
            now: now))
    }

    // The exact expiry instant is treated as expired (strict greater-than), so a
    // transaction whose window closes precisely "now" does not grant Pro.
    func testExpiryExactlyNowDoesNotGrantPro() {
        XCTAssertFalse(StoreKitPurchaseService.transactionGrantsProNow(
            productID: ProductMapping.monthlyID,
            isRevoked: false,
            expirationDate: now,
            now: now))
    }
}
