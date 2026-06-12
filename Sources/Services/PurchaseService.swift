// PurchaseService.swift — the purchasing seam (M3).
//
// The paywall talks to this protocol; `StoreKitPurchaseService` is the
// production implementation, `SimulatedPurchaseService` serves SwiftUI
// previews. Product → plan mapping is pure (`ProductMapping`) so pricing,
// the savings tag, and trial copy are unit-tested without StoreKit.
//
// Pro entitlement: NEVER a stored flag. AppState.isPro mirrors
// `StoreKitPurchaseService.currentEntitlementIsPro()` (checked at launch and
// on every Transaction.updates event — wired in TapeMeasureARProApp).

import Foundation
import Observation

// MARK: - Legal links

/// Centralized legal URLs surfaced on the paywall and in Settings
/// (Guideline 3.1.2 requires functional Terms/EULA + privacy policy links).
/// Hosted from the github.com/faisalarip/tapescan-legal repository (sources
/// in legal-site/); the same privacy/support URLs go in App Store Connect.
public enum LegalLinks {
    /// TapeScan Terms of Use (incorporates Apple's standard EULA).
    public static let terms = URL(string: "https://faisalarip.github.io/tapescan-legal/terms.html")!
    /// TapeScan privacy policy.
    public static let privacy = URL(string: "https://faisalarip.github.io/tapescan-legal/privacy.html")!
    /// Support page.
    public static let support = URL(string: "https://faisalarip.github.io/tapescan-legal/support.html")!
}

// MARK: - Offering model

/// A purchasable plan surfaced on the paywall. `id` is the App Store product
/// identifier; `displayName` is the row title ("Monthly" / "Annual" / "Lifetime").
public struct SubscriptionPlan: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    /// Localized headline price from StoreKit, e.g. `"$4.99"`.
    public let price: String
    /// Secondary line under the title, e.g. `"$2.08 / mo · billed yearly"`.
    public let subtitle: String
    /// Optional savings tag, e.g. `"SAVE 58%"` — computed from real prices.
    public let tag: String?
    /// Optional struck-through anchor substantiating `tag` (12 × monthly).
    public let compareAt: String?
    /// Billing period word for the disclosure (`"month"` / `"year"`); nil = one-time.
    public let period: String?
    /// True only when the product has a configured introductory offer.
    public let hasTrial: Bool

    public init(id: String,
                displayName: String,
                price: String,
                subtitle: String,
                tag: String? = nil,
                compareAt: String? = nil,
                period: String?,
                hasTrial: Bool) {
        self.id = id
        self.displayName = displayName
        self.price = price
        self.subtitle = subtitle
        self.tag = tag
        self.compareAt = compareAt
        self.period = period
        self.hasTrial = hasTrial
    }

    /// CTA label — trial plans start the trial, others unlock at the shown price.
    public var ctaLabel: String {
        hasTrial ? "Start Free 7-day Trial" : "Unlock \(displayName) · \(price)"
    }

    /// Required App Store billing disclosure (Guideline 3.1.2), per plan —
    /// always names the exact post-trial price.
    public var disclosure: String {
        if hasTrial {
            let per = period ?? "period"
            return "Free for 7 days, then \(price)/\(per). Auto-renews until canceled. Cancel anytime in Settings."
        }
        if period != nil {
            return "\(price)/\(period!). Auto-renews until canceled. Cancel anytime in Settings."
        }
        return "One-time purchase. No subscription."
    }
}

/// Outcome of a purchase / restore attempt.
public enum PurchaseResult: Sendable {
    case success
    case cancelled
    case failed(String)
}

/// Product-fetch lifecycle the paywall renders.
public enum PurchaseLoadState: Equatable, Sendable {
    case loading
    case loaded
    case failed(String)
}

// MARK: - Pure product → plan mapping

/// Minimal, StoreKit-free description of a fetched product.
public struct ProductInfo: Equatable, Sendable {
    public enum PeriodKind: Equatable, Sendable { case month, year }
    public var id: String
    public var displayPrice: String
    public var price: Decimal
    public var period: PeriodKind?
    public var hasIntroOffer: Bool

    public init(id: String, displayPrice: String, price: Decimal,
                period: PeriodKind?, hasIntroOffer: Bool) {
        self.id = id
        self.displayPrice = displayPrice
        self.price = price
        self.period = period
        self.hasIntroOffer = hasIntroOffer
    }
}

public enum ProductMapping {
    public static let monthlyID = "tapescan.pro.monthly"
    public static let annualID = "tapescan.pro.annual"
    public static let lifetimeID = "tapescan.pro.lifetime"
    public static let allIDs = [monthlyID, annualID, lifetimeID]
    /// The design pre-selects Annual.
    public static let defaultSelectionID = annualID

    /// Maps fetched products into display plans (Monthly → Annual → Lifetime).
    /// `formatPrice` localizes derived prices (anchor, per-month equivalent)
    /// using the storefront's currency format.
    public static func plans(from infos: [ProductInfo],
                             formatPrice: (Decimal) -> String) -> [SubscriptionPlan] {
        let byID = Dictionary(infos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var plans: [SubscriptionPlan] = []

        if let monthly = byID[monthlyID] {
            plans.append(SubscriptionPlan(id: monthly.id,
                                          displayName: "Monthly",
                                          price: monthly.displayPrice,
                                          subtitle: "per month",
                                          period: "month",
                                          hasTrial: monthly.hasIntroOffer))
        }
        if let annual = byID[annualID] {
            var tag: String?
            var compareAt: String?
            if let monthly = byID[monthlyID], monthly.price > 0 {
                let anchor = monthly.price * 12
                if anchor > annual.price {
                    let fraction = NSDecimalNumber(decimal: (anchor - annual.price)).doubleValue
                        / NSDecimalNumber(decimal: anchor).doubleValue
                    tag = "SAVE \(Int((fraction * 100).rounded()))%"
                    compareAt = formatPrice(anchor)
                }
            }
            let perMonth = annual.price / 12
            plans.append(SubscriptionPlan(id: annual.id,
                                          displayName: "Annual",
                                          price: annual.displayPrice,
                                          subtitle: "\(formatPrice(perMonth)) / mo · billed yearly",
                                          tag: tag,
                                          compareAt: compareAt,
                                          period: "year",
                                          hasTrial: annual.hasIntroOffer))
        }
        if let lifetime = byID[lifetimeID] {
            plans.append(SubscriptionPlan(id: lifetime.id,
                                          displayName: "Lifetime",
                                          price: lifetime.displayPrice,
                                          subtitle: "one-time purchase",
                                          period: nil,
                                          hasTrial: false))
        }
        return plans
    }
}

// MARK: - Service seam

@MainActor
public protocol PurchaseService: AnyObject, Observable {
    var loadState: PurchaseLoadState { get }
    /// The offerings to render, in display order. Empty until loaded.
    var plans: [SubscriptionPlan] { get }
    /// Plan id pre-selected when the paywall opens.
    var defaultSelectionID: String { get }
    /// Fetch products from the store (idempotent; safe to retry).
    func loadProducts() async
    /// Begin a purchase for the given plan.
    func purchase(_ plan: SubscriptionPlan) async -> PurchaseResult
    /// Restore previously-purchased entitlements.
    func restore() async -> PurchaseResult
}

/// Preview-only backend: canned plans, instant success. Never shipped as the
/// default — production paths construct ``StoreKitPurchaseService``.
@MainActor
@Observable
public final class SimulatedPurchaseService: PurchaseService {
    public private(set) var loadState: PurchaseLoadState = .loaded
    public private(set) var plans: [SubscriptionPlan]
    public let defaultSelectionID = ProductMapping.defaultSelectionID

    public init() {
        let usd: (Decimal) -> String = {
            "$" + String(format: "%.2f", NSDecimalNumber(decimal: $0).doubleValue)
        }
        plans = ProductMapping.plans(from: [
            ProductInfo(id: ProductMapping.monthlyID, displayPrice: "$4.99",
                        price: 4.99, period: .month, hasIntroOffer: true),
            ProductInfo(id: ProductMapping.annualID, displayPrice: "$24.99",
                        price: 24.99, period: .year, hasIntroOffer: true),
            ProductInfo(id: ProductMapping.lifetimeID, displayPrice: "$59.99",
                        price: 59.99, period: nil, hasIntroOffer: false),
        ], formatPrice: usd)
    }

    public func loadProducts() async {}
    public func purchase(_ plan: SubscriptionPlan) async -> PurchaseResult { .success }
    public func restore() async -> PurchaseResult { .success }
}
