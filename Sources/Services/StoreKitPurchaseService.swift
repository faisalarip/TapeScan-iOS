// StoreKitPurchaseService.swift — production purchasing via StoreKit 2 (M3).
//
// Verified transactions only; entitlement state always derives from
// `Transaction.currentEntitlements` (launch check + `Transaction.updates`
// listener in TapeMeasureARProApp), never from a stored flag. Locally
// testable with the TapeScan.storekit configuration referenced by the
// shared scheme — no App Store Connect required for Simulator verification.

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
public final class StoreKitPurchaseService: PurchaseService {

    public private(set) var loadState: PurchaseLoadState = .loading
    public private(set) var plans: [SubscriptionPlan] = []
    public let defaultSelectionID = ProductMapping.defaultSelectionID

    /// Fetched products keyed by product ID.
    private var products: [String: Product] = [:]

    public init() {}

    // MARK: - Products

    public func loadProducts() async {
        loadState = .loading
        do {
            let fetched = try await Product.products(for: ProductMapping.allIDs)
            guard let first = fetched.first else {
                loadState = .failed("Plans aren't available right now. Check your connection and try again.")
                return
            }
            products = Dictionary(fetched.map { ($0.id, $0) },
                                  uniquingKeysWith: { a, _ in a })
            let style = first.priceFormatStyle
            let infos = fetched.map { product in
                ProductInfo(id: product.id,
                            displayPrice: product.displayPrice,
                            price: product.price,
                            currencyCode: product.priceFormatStyle.currencyCode,
                            period: Self.periodKind(of: product),
                            hasIntroOffer: product.subscription?.introductoryOffer != nil)
            }
            plans = ProductMapping.plans(from: infos) { $0.formatted(style) }
            loadState = plans.isEmpty
                ? .failed("Plans aren't available right now. Check your connection and try again.")
                : .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private static func periodKind(of product: Product) -> ProductInfo.PeriodKind? {
        switch product.subscription?.subscriptionPeriod.unit {
        case .year:  return .year
        case .month: return .month
        default:     return nil
        }
    }

    // MARK: - Purchase / restore

    public func purchase(_ plan: SubscriptionPlan) async -> PurchaseResult {
        guard let product = products[plan.id] else {
            return .failed("That plan isn't available right now.")
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("The purchase could not be verified.")
                }
                // Capture the revenue facts BEFORE finishing so the paywall can
                // log a GA4 `purchase` event with value + currency + transaction id.
                let receipt = PurchaseReceipt(
                    value: product.price,
                    currency: product.priceFormatStyle.currencyCode,
                    transactionID: String(transaction.id))
                await transaction.finish()
                return .success(receipt)
            case .userCancelled:
                return .cancelled
            case .pending:
                return .failed("The purchase is pending approval (Ask to Buy). Pro unlocks automatically once approved.")
            @unknown default:
                return .failed("The purchase did not complete.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    public func restore() async -> PurchaseResult {
        do {
            try await AppStore.sync()
        } catch {
            return .failed(error.localizedDescription)
        }
        return await Self.currentEntitlementIsPro()
            ? .success(nil)
            : .failed("No previous purchases were found for this Apple Account.")
    }

    // MARK: - Entitlement (the single source of isPro)

    /// True when any verified, unrevoked TapeScan Pro entitlement is current
    /// (active subscription or the lifetime unlock).
    public static func currentEntitlementIsPro() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               ProductMapping.allIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    /// Display snapshot of the user's current Pro entitlement (plan + renewal),
    /// for the Settings status card. `nil` when there's no active entitlement.
    /// Reads the same verified, unrevoked, Apple-ID-level source as
    /// `currentEntitlementIsPro`.
    public struct EntitlementSummary: Equatable, Sendable {
        public let productID: String
        public let isLifetime: Bool
        /// Next renewal / expiry for subscriptions; `nil` for the lifetime unlock.
        public let expirationDate: Date?
    }

    public static func currentEntitlement() async -> EntitlementSummary? {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               ProductMapping.allIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                return EntitlementSummary(
                    productID: transaction.productID,
                    isLifetime: transaction.productID == ProductMapping.lifetimeID,
                    expirationDate: transaction.expirationDate)
            }
        }
        return nil
    }

    /// Pure decision: does a just-received transaction, on its own, prove a
    /// CURRENT Pro entitlement? Kept free of StoreKit types (like ``ProductMapping``)
    /// so the "a fresh grant can't be clobbered by a lagging snapshot" rule is
    /// unit-tested. A transaction grants Pro now iff it's a Pro product, not
    /// revoked/refunded, and not past its expiry (a nil `expirationDate` is the
    /// lifetime non-consumable, which never expires).
    nonisolated static func transactionGrantsProNow(productID: String,
                                                     isRevoked: Bool,
                                                     expirationDate: Date?,
                                                     now: Date) -> Bool {
        guard !isRevoked, ProductMapping.allIDs.contains(productID) else { return false }
        if let expiry = expirationDate { return expiry > now }
        return true
    }

    /// Long-running listener: finishes incoming verified transactions
    /// (renewals, Ask-to-Buy approvals, refunds) and reports the resolved
    /// entitlement. Run from the app root's `.task`.
    ///
    /// The callback is widened beyond the bare `isPro` flag so the analytics
    /// seam can fire a `subscription_status_change` event for out-of-band
    /// entitlement changes (renewals, refunds, Ask-to-Buy approvals) that
    /// arrive without a live paywall source. `productID` lets the caller map
    /// to a plan kind, and `isRefund` (derived from the verified transaction's
    /// `revocationDate`) lets it distinguish a refund from a renewal/purchase.
    /// For unverified updates there is no transaction to read, so the defaults
    /// (`productID == ""`, `isRefund == false`) are passed — the caller must
    /// NOT treat these as a new revenue conversion.
    public static func listenForTransactionUpdates(onChange: @escaping @MainActor (_ isPro: Bool, _ productID: String, _ isRefund: Bool) -> Void) async {
        for await update in Transaction.updates {
            // Capture attribution-relevant facts only from verified transactions.
            var productID = ""
            var isRefund = false
            // Does THIS update, by itself, prove a current Pro entitlement?
            // `Transaction.currentEntitlements` lags briefly right after a
            // purchase in the StoreKit-testing / Sandbox environments, so the
            // recompute below can momentarily return `false` for an entitlement
            // that was just granted. We OR this fresh-grant fact in so the
            // listener can never downgrade a just-verified purchase back to
            // `false` — the exact race that made the paywall/Pro card require a
            // second subscribe to stick.
            var grantsProNow = false
            if case .verified(let transaction) = update {
                productID = transaction.productID
                isRefund = transaction.revocationDate != nil
                grantsProNow = transactionGrantsProNow(
                    productID: transaction.productID,
                    isRevoked: isRefund,
                    expirationDate: transaction.expirationDate,
                    now: Date())
                await transaction.finish()
            }
            // Refunds/expirations still flip Pro off via the authoritative
            // recompute (grantsProNow is false for those); only a valid, fresh
            // grant forces `true` regardless of snapshot lag.
            let isPro = await currentEntitlementIsPro() || grantsProNow
            await MainActor.run { onChange(isPro, productID, isRefund) }
        }
    }
}
