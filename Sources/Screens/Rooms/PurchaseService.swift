// PurchaseService.swift — RevenueCat-style purchasing seam (stub, no real keys).
//
// The Paywall talks to this protocol, never to a concrete SDK. A real build would
// drop in a `RevenueCatPurchaseService` that wraps `Purchases.shared` and maps
// `Package`/`StoreProduct` → ``SubscriptionPlan``; nothing in the UI changes.
//
// Mirrors the App Store-ready paywall model from the verified HTML reference:
//   • Monthly / Annual (SAVE 58%) / Lifetime offerings
//   • per-plan trial flag → drives the CTA copy + billing disclosure (Guideline 3.1.2)
//   • restore / terms / privacy entry points

import Foundation

// MARK: - Legal links (reskin config)

/// Centralized legal URLs surfaced on the paywall (Guideline 3.1.2 requires
/// functional links to the terms of use / EULA and privacy policy). A reskinning
/// buyer changes these two constants and nothing else. The defaults point at
/// Apple's standard EULA and a placeholder privacy page — replace before submitting.
public enum LegalLinks {
    /// Terms of Use (EULA). Defaults to Apple's standard EULA.
    public static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Privacy policy. Replace with the app's hosted policy before submission.
    public static let privacy = URL(string: "https://www.apple.com/legal/privacy/")!
}

// MARK: - Offering model

/// A purchasable plan surfaced on the paywall. Value type — the data layer maps a
/// store `Package` into this at the service boundary.
public struct SubscriptionPlan: Identifiable, Hashable, Sendable {
    /// Stable identifier (also the display key: "Monthly" / "Annual" / "Lifetime").
    public let id: String
    /// Localized headline price, e.g. `"$4.99"`.
    public let price: String
    /// Secondary line under the title, e.g. `"$2.08 / mo · billed yearly"`.
    public let subtitle: String
    /// Optional savings tag, e.g. `"SAVE 58%"`.
    public let tag: String?
    /// Optional struck-through anchor price that substantiates `tag`, e.g. the
    /// monthly-rate-times-twelve for an annual plan (`"$59.88"` vs `"$24.99"`).
    /// Rendered with a strikethrough next to `price`; `nil` hides the anchor.
    public let compareAt: String?
    /// Billing period word for the disclosure (`"month"` / `"year"`); `nil` for one-time.
    public let period: String?
    /// Whether this plan opens with a free trial (drives CTA + disclosure copy).
    public let hasTrial: Bool

    public init(id: String,
                price: String,
                subtitle: String,
                tag: String? = nil,
                compareAt: String? = nil,
                period: String?,
                hasTrial: Bool) {
        self.id = id
        self.price = price
        self.subtitle = subtitle
        self.tag = tag
        self.compareAt = compareAt
        self.period = period
        self.hasTrial = hasTrial
    }

    /// CTA label for this plan — trial plans start the trial, one-time plans unlock.
    /// Matches the HTML: "Start Free 7-day Trial" vs "Unlock Lifetime · $59.99".
    public var ctaLabel: String {
        hasTrial ? "Start Free 7-day Trial" : "Unlock \(id) · \(price)"
    }

    /// Required App Store billing disclosure (Guideline 3.1.2), adapted per plan.
    public var disclosure: String {
        if hasTrial {
            let per = period ?? "period"
            return "Free for 7 days, then \(price)/\(per). Auto-renews until canceled. Cancel anytime in Settings."
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

// MARK: - Service seam

/// Purchasing abstraction the paywall depends on. A concrete RevenueCat-backed
/// implementation is injected in production; the stub below runs everywhere.
@MainActor
public protocol PurchaseService: AnyObject {
    /// The offerings to render, in display order (Monthly → Annual → Lifetime).
    var plans: [SubscriptionPlan] { get }
    /// Plan id pre-selected when the paywall opens (the design defaults to Annual).
    var defaultSelectionID: String { get }
    /// Begin a purchase for the given plan.
    func purchase(_ plan: SubscriptionPlan) async -> PurchaseResult
    /// Restore previously-purchased entitlements.
    func restore() async -> PurchaseResult
}

/// In-memory RevenueCat-style stub. No network, no keys — returns canned offerings
/// and reports success so the flow is demonstrable in the Simulator.
@MainActor
public final class StubPurchaseService: PurchaseService {

    public let plans: [SubscriptionPlan]
    public let defaultSelectionID: String

    public nonisolated init() {
        self.plans = [
            SubscriptionPlan(id: "Monthly",
                             price: "$4.99",
                             subtitle: "per month",
                             tag: nil,
                             period: "month",
                             hasTrial: true),
            SubscriptionPlan(id: "Annual",
                             price: "$24.99",
                             subtitle: "$2.08 / mo · billed yearly",
                             tag: "SAVE 58%",
                             // 12 × $4.99 monthly = $59.88 — substantiates "SAVE 58%".
                             compareAt: "$59.88",
                             period: "year",
                             hasTrial: true),
            SubscriptionPlan(id: "Lifetime",
                             price: "$59.99",
                             subtitle: "one-time purchase",
                             tag: nil,
                             period: nil,
                             hasTrial: false),
        ]
        // Source default: Annual selected.
        self.defaultSelectionID = "Annual"
    }

    public func purchase(_ plan: SubscriptionPlan) async -> PurchaseResult {
        // A real impl would call `Purchases.shared.purchase(package:)`.
        .success
    }

    public func restore() async -> PurchaseResult {
        // A real impl would call `Purchases.shared.restorePurchases()`.
        .success
    }
}
