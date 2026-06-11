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
                await transaction.finish()
                return .success
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
            ? .success
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

    /// Long-running listener: finishes incoming verified transactions
    /// (renewals, Ask-to-Buy approvals, refunds) and reports the recomputed
    /// entitlement. Run from the app root's `.task`.
    public static func listenForTransactionUpdates(onChange: @escaping @MainActor (Bool) -> Void) async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
            }
            let isPro = await currentEntitlementIsPro()
            await MainActor.run { onChange(isPro) }
        }
    }
}
