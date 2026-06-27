// PaywallView.swift — RevenueCat-style PRO paywall.
// Ported 1:1 from onboarding.jsx `Paywall` + the verified HTML reference.
//
// Structure:
//   • hero band (accent gradient) with close, PRO badge, headline, "used all 3 free exports"
//   • perks list (check rows)
//   • selectable plans (Monthly / Annual SAVE 58% / Lifetime) — radio group
//   • CTA bound to the selected plan ("Start Free 7-day Trial" / "Unlock Lifetime · $59.99")
//   • per-plan billing disclosure (Guideline 3.1.2) + Restore / Terms / Privacy links
//
// Purchasing goes through ``PurchaseService`` (a RevenueCat-style stub) — no SDK,
// no keys. The UI never names a concrete vendor.

import SwiftUI

/// Why the paywall was presented. Drives the (truthful) hero sub-headline so the
/// store copy never claims "you've used all your exports" when the user still has
/// quota — a proactive upsell shows an honest "go unlimited" line instead.
public enum PaywallContext: Sendable {
    /// Opened because the free export quota was exhausted (Export flow at 0 left).
    /// Renders the canonical 1:1 source string verbatim.
    case quotaExhausted
    /// Opened proactively (Settings upsell / mid-quota) with `freeExportsLeft` left.
    case proactive(freeExportsLeft: Int)

    /// Low-cardinality string for the GA4 `paywall_context` custom dimension.
    /// Stable across the two `proactive` shapes so the funnel groups cleanly;
    /// never carries the (variable) `freeExportsLeft` count — that rides its own
    /// `free_exports_left` parameter on the impression event.
    var analyticsName: String {
        switch self {
        case .quotaExhausted: return "quota_exhausted"
        case .proactive:      return "proactive"
        }
    }
}

public struct PaywallView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    /// Injected purchasing seam (StoreKit 2 in production).
    private let service: any PurchaseService
    /// Why the sheet was opened — selects a non-false hero sub-headline.
    private let context: PaywallContext
    /// Dismiss handler (close button + successful purchase).
    private let onClose: () -> Void

    @State private var selectionID: String
    @State private var isWorking = false
    @State private var showAuthSheet = false
    @State private var pendingPlan: SubscriptionPlan?

    public init(service: any PurchaseService,
                context: PaywallContext = .quotaExhausted,
                onClose: @escaping () -> Void = {}) {
        self.service = service
        self.context = context
        self.onClose = onClose
        _selectionID = State(initialValue: service.defaultSelectionID)
    }

    /// Production entry point: real StoreKit 2 purchasing.
    @MainActor
    public init(context: PaywallContext = .quotaExhausted,
                onClose: @escaping () -> Void = {}) {
        self.init(service: StoreKitPurchaseService(),
                  context: context,
                  onClose: onClose)
    }

    /// Hero sub-headline. Quota-exhausted keeps the source string 1:1; a proactive
    /// open shows an honest, non-false alternative.
    private var subheadline: String {
        switch context {
        case .quotaExhausted:
            return "You've used all 3 free exports."
        case .proactive(let left) where left <= 0:
            // Defensive: a "proactive" open with no quota is really exhausted.
            return "You've used all 3 free exports."
        case .proactive(let left):
            let noun = left == 1 ? "export" : "exports"
            return "Go unlimited with Pro — \(left) of 3 free \(noun) left."
        }
    }

    // MARK: - Derived

    /// Nil while products are loading / failed — the footer CTA hides with it,
    /// which also removes the historical `plans[0]` crash on empty fetches.
    private var selectedPlan: SubscriptionPlan? {
        service.plans.first { $0.id == selectionID } ?? service.plans.first
    }

    private static let perks: [(icon: String, label: String)] = [
        ("cube3d", "USDZ + glTF 3D model export"),
        ("download", "Unlimited exports — no quota"),
        ("room", "Unlimited saved rooms & history"),
        ("ruler2", "High-precision LiDAR mode"),
        ("layers", "Watermark-free floor plans"),
    ]

    public var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Scrollable content so the paywall fits every device + Dynamic
                // Type size (small iPhones can't show 5 perks + 3 plans at once;
                // iPad has lots of room). The footer (CTA + required billing
                // disclosure) stays pinned below, so the purchase button is always
                // reachable without scrolling.
                ScrollView {
                    VStack(spacing: 0) {
                        hero
                        perksList
                            .padding(.horizontal, 22)
                            .padding(.top, 6)
                        plansArea
                            .padding(.horizontal, 22)
                            .padding(.top, 18)
                    }
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity)
                }
                footer
            }
        }
        .task {
            if service.plans.isEmpty { await service.loadProducts() }
            if selectionID.isEmpty { selectionID = service.defaultSelectionID }

            // IMPRESSION (paywall_view). `recordImpression()` bumps the session
            // touchpoint_count and the per-source tally, then returns the live
            // source (pendingSource set by the trigger site's `beginPaywall`).
            // The first/last value-feature ride along so GA4 can attribute which
            // feature seeded this view. A no-op when analytics are disabled.
            let src = appState.attribution.recordImpression()
            appState.analytics.log(AnalyticsEventName.paywallView, [
                AnalyticsParam.paywallSource: .string(src ?? "unknown"),
                AnalyticsParam.paywallContext: .string(context.analyticsName),
                AnalyticsParam.freeExportsLeft: .int(appState.freeExportsLeft),
                AnalyticsParam.isAuthenticated: .bool(appState.isAuthenticated),
                AnalyticsParam.touchpointCount: .int(appState.attribution.touchpointCount),
                AnalyticsParam.firstValueFeature: .string(appState.attribution.firstValueFeature ?? "none"),
                AnalyticsParam.lastValueFeature: .string(appState.attribution.lastValueFeature ?? "none"),
            ])
        }
        // Surface purchase/restore failures even though this is presented as a cover.
        .appAlert(appState)
        .sheet(isPresented: $showAuthSheet) {
            AuthFlowView(onDone: {
                showAuthSheet = false
                // Continue the gated purchase only if they actually signed in.
                if appState.isAuthenticated, let plan = pendingPlan {
                    pendingPlan = nil
                    Task { await commitPurchase(plan) }
                } else {
                    pendingPlan = nil
                }
            })
            .environment(appState)
            .installTheme(Theme(appState))
        }
    }

    // MARK: - Hero band

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Icon("close", size: 16, weight: 2.2, color: Theme.ink2)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44, alignment: .trailing)
                .accessibilityLabel("Close")
            }

            // PRO badge
            HStack(spacing: 7) {
                Icon("cube3d", size: 14, weight: 2, color: .white)
                Text("PRO")
            }
            .font(Theme.mono(11, weight: .bold))
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(theme.accent.withA(0.92)))
            .padding(.top, 6)

            Text("Unlock the full toolkit")
                .font(Theme.sans(28, weight: .bold))
                .tracking(-0.6)
                .lineSpacing(2)
                .foregroundStyle(Theme.ink)
                .padding(.top, 14)
            Text(subheadline)
                .font(Theme.sans(14.5))
                .foregroundStyle(Theme.ink2)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 54)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [theme.accent.withA(0.4), .clear],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    // MARK: - Perks

    private var perksList: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(Self.perks, id: \.label) { perk in
                HStack(spacing: 12) {
                    Icon("check", size: 15, weight: 2.6, color: theme.accent)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: theme.r(8), style: .continuous)
                                .fill(theme.accent.withA(0.18)))
                    Text(perk.label)
                        .font(Theme.sans(14.5))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plans (radio group + load states)

    @ViewBuilder
    private var plansArea: some View {
        switch service.loadState {
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                    .tint(theme.accent)
                Text("Loading plans…")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(Theme.sans(13.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink2)
                Button {
                    Task { await service.loadProducts() }
                } label: {
                    Text("Try Again")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Try loading plans again")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        case .loaded:
            VStack(spacing: 9) {
                ForEach(service.plans) { plan in
                    planRow(plan)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Choose a plan")
        }
    }

    private func planRow(_ plan: SubscriptionPlan) -> some View {
        let on = plan.id == selectionID
        return Button {
            selectionID = plan.id
            // PLAN SELECTED (paywall_plan_selected). Carries the live source so
            // GA4 can see which entry points drive which plan choices, plus the
            // bucketed plan_kind and whether this plan offers a free trial.
            appState.analytics.log(AnalyticsEventName.paywallPlanSelected, [
                AnalyticsParam.paywallSource: .string(appState.attribution.conversionSource ?? "unknown"),
                AnalyticsParam.productId: .string(plan.id),
                AnalyticsParam.planKind: .string(PlanKind.from(productID: plan.id)),
                AnalyticsParam.hasTrial: .bool(plan.hasTrial),
            ])
        } label: {
            HStack(spacing: 13) {
                // radio dot
                ZStack {
                    Circle()
                        .strokeBorder(on ? theme.accent : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if on {
                        Circle().fill(theme.accent).frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(plan.displayName)
                            .font(Theme.sans(15.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if let tag = plan.tag {
                            Text(tag)
                                .font(Theme.mono(9.5, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Theme.iosGreen))
                        }
                    }
                    Text(plan.subtitle)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.ink3)
                }

                Spacer(minLength: 8)

                // Price column: optional struck-through anchor above the price so
                // the savings tag ("SAVE 58%") is substantiated (e.g. ~~$59.88~~).
                VStack(alignment: .trailing, spacing: 1) {
                    if let was = plan.compareAt {
                        Text(was)
                            .font(Theme.sans(11.5, weight: .medium))
                            .foregroundStyle(Theme.ink3)
                            .strikethrough(true, color: Theme.ink3)
                            .accessibilityHidden(true)
                    }
                    Text(plan.price)
                        .font(Theme.sans(16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: theme.r(15), style: .continuous)
                    .fill(on ? theme.accent.withA(0.14) : Color.white.opacity(0.04)))
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(15), style: .continuous)
                    .strokeBorder(on ? theme.accent : Color.white.opacity(0.1),
                                  lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
        .accessibilityLabel("\(plan.displayName), \(plan.price)"
            + (plan.compareAt.map { ", was \($0)" } ?? "")
            + (plan.tag.map { ", \($0)" } ?? ""))
    }

    // MARK: - Footer (CTA + disclosure + legal links)

    private var footer: some View {
        VStack(spacing: 10) {
            if let plan = selectedPlan {
                PrimaryButton(title: plan.ctaLabel) {
                    // PURCHASE START (paywall_purchase_start). Logged BEFORE the
                    // sign-in gate so the funnel captures intent even when the
                    // purchase is deferred behind account creation; requires_signin
                    // records exactly that deferral.
                    appState.analytics.log(AnalyticsEventName.paywallPurchaseStart, [
                        AnalyticsParam.paywallSource: .string(appState.attribution.conversionSource ?? "unknown"),
                        AnalyticsParam.productId: .string(plan.id),
                        AnalyticsParam.planKind: .string(PlanKind.from(productID: plan.id)),
                        AnalyticsParam.requiresSignin: .bool(!appState.isAuthenticated),
                    ])
                    // Require an account before subscribing — Pro includes cloud sync
                    // of unlimited rooms/history, so the subscription is account-tied.
                    if appState.isAuthenticated {
                        Task { await commitPurchase(plan) }
                    } else {
                        pendingPlan = plan
                        showAuthSheet = true
                    }
                }
                .accessibilityLabel(plan.ctaLabel)
                .disabled(isWorking)
                .opacity(isWorking ? 0.6 : 1)

                // Required App Store billing disclosure (Guideline 3.1.2) —
                // always names the exact post-trial price.
                Text(plan.disclosure)
                    .font(Theme.sans(10.5))
                    .lineSpacing(1.5)
                    .foregroundStyle(Theme.ink3)
                    .multilineTextAlignment(.center)
                    // Never truncate the required auto-renew billing terms (Guideline
                    // 3.1.2) when vertical space is tight — wrap to full height.
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }

            HStack(spacing: 14) {
                legalLink("Restore") { Task { await commitRestore() } }
                // Functional links to the EULA / privacy policy (Guideline 3.1.2).
                legalLink("Terms") { openURL(LegalLinks.terms) }
                legalLink("Privacy") { openURL(LegalLinks.privacy) }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 34)
    }

    private func legalLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(12.5, weight: .medium))
                .foregroundStyle(Theme.ink3)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Actions

    private func commitPurchase(_ plan: SubscriptionPlan) async {
        guard !isWorking else { return }
        isWorking = true
        let result = await service.purchase(plan)
        isWorking = false

        // Resolve the attribution + plan facts once; reused by every branch so the
        // funnel events all carry a consistent source/plan_kind/product_id.
        let src = appState.attribution.conversionSource ?? "unknown"
        let kind = PlanKind.from(productID: plan.id)

        switch result {
        case .success(let receipt):
            // The service returns .success only for a verified, finished
            // transaction; the Transaction.updates listener keeps this in sync.

            // Custom funnel conversion event (paywall_purchase_success) — the
            // headline "which entry point converts" signal. Carries the full
            // attribution spine: touchpoints, first/last value-feature, and the
            // sessions/time-to-convert state.
            appState.analytics.log(AnalyticsEventName.paywallPurchaseSuccess, [
                AnalyticsParam.paywallSource: .string(src),
                AnalyticsParam.productId: .string(plan.id),
                AnalyticsParam.planKind: .string(kind),
                AnalyticsParam.touchpointCount: .int(appState.attribution.touchpointCount),
                AnalyticsParam.firstValueFeature: .string(appState.attribution.firstValueFeature ?? "none"),
                AnalyticsParam.lastValueFeature: .string(appState.attribution.lastValueFeature ?? "none"),
                AnalyticsParam.sessionsToConvert: .int(appState.attribution.sessionCount),
                AnalyticsParam.timeToConvertBucket: .string(appState.attribution.timeToConvertBucket(now: Date())),
            ])

            // GA4 RESERVED revenue event (purchase) — lights up monetization
            // reports and lets entry points be ranked by REVENUE, not just count
            // (a $59.99 lifetime vs a $4.99 trial-start are no longer identical).
            // GA4 DROPS `value` unless `currency` (ISO-4217) is sent WITH it, so we
            // attach value + currency + transaction_id only when the verified
            // receipt carries a currency, and omit all three otherwise rather than
            // send a partial GA4 would discard. (`items` stays deferred — Firebase
            // wants an array of dicts, not an AnalyticsValue.)
            var purchaseParams: [String: AnalyticsValue] = [
                AnalyticsParam.paywallSource: .string(src),
                AnalyticsParam.planKind: .string(kind),
                AnalyticsParam.productId: .string(plan.id),
                AnalyticsParam.touchpointCount: .int(appState.attribution.touchpointCount),
            ]
            if let receipt, let currency = receipt.currency {
                purchaseParams[AnalyticsParam.value] =
                    .double(NSDecimalNumber(decimal: receipt.value).doubleValue)
                purchaseParams[AnalyticsParam.currency] = .string(currency)
                if let transactionID = receipt.transactionID {
                    purchaseParams[AnalyticsParam.transactionId] = .string(transactionID)
                }
            }
            appState.analytics.log(AnalyticsEventName.purchase, purchaseParams)

            // User properties — segment all future events by entitlement + plan.
            appState.analytics.setUserProperty("true", for: .isPro)
            appState.analytics.setUserProperty(kind, for: .planKind)

            appState.isPro = true
            onClose()
        case .cancelled:
            appState.analytics.log(AnalyticsEventName.paywallPurchaseCancelled, [
                AnalyticsParam.paywallSource: .string(src),
                AnalyticsParam.productId: .string(plan.id),
                AnalyticsParam.planKind: .string(kind),
            ])
        case .failed(let message):
            // Ask-to-Buy (pending) is NOT a failure — the real approval lands later
            // via the StoreKit listener (attributed to the persisted lastSource).
            // PurchaseResult folds .pending into .failed, so we special-case its
            // exact message string (StoreKitPurchaseService pending case).
            if message == Self.askToBuyPendingMessage {
                appState.analytics.log(AnalyticsEventName.paywallPurchasePending, [
                    AnalyticsParam.paywallSource: .string(src),
                    AnalyticsParam.productId: .string(plan.id),
                    AnalyticsParam.planKind: .string(kind),
                ])
            } else {
                // failure_reason is a BUCKETED enum string — never the raw
                // localized message (which would be high-cardinality PII-adjacent).
                appState.analytics.log(AnalyticsEventName.paywallPurchaseFailed, [
                    AnalyticsParam.paywallSource: .string(src),
                    AnalyticsParam.productId: .string(plan.id),
                    AnalyticsParam.planKind: .string(kind),
                    AnalyticsParam.failureReason: .string(Self.failureBucket(for: message)),
                ])
                appState.presentAlert(title: "Purchase didn't complete", message: message)
            }
        }
    }

    /// The exact pending message produced by `StoreKitPurchaseService` for an
    /// Ask-to-Buy purchase (which `PurchaseResult` folds into `.failed`). Matched
    /// verbatim so the pending case logs `paywall_purchase_pending` instead of a
    /// false `paywall_purchase_failed`. Kept in sync with that service.
    private static let askToBuyPendingMessage =
        "The purchase is pending approval (Ask to Buy). Pro unlocks automatically once approved."

    /// Collapse a raw failure message into a low-cardinality GA4 bucket. We never
    /// send the localized string itself (high cardinality, locale-dependent, and
    /// potentially user-identifying). Heuristic by content; defaults to "other".
    private static func failureBucket(for message: String) -> String {
        let m = message.lowercased()
        if m.contains("verif") { return "unverified" }
        if m.contains("network") || m.contains("internet") || m.contains("connection") { return "network" }
        if m.contains("unavailable") || m.contains("not available") || m.contains("could not load") { return "unavailable" }
        return "other"
    }

    private func commitRestore() async {
        guard !isWorking else { return }
        isWorking = true
        let result = await service.restore()
        isWorking = false
        switch result {
        case .success:
            // restore_origin=paywall distinguishes this from the Settings restore
            // path. A restore is NOT a new conversion, so it never fires the GA4
            // reserved `purchase` event — only the funnel restore result.
            appState.analytics.log(AnalyticsEventName.paywallRestoreResult, [
                AnalyticsParam.result: .string("success"),
                AnalyticsParam.restoreOrigin: .string("paywall"),
            ])
            appState.analytics.setUserProperty("true", for: .isPro)
            appState.isPro = true
            onClose()
        case .cancelled:
            appState.analytics.log(AnalyticsEventName.paywallRestoreResult, [
                AnalyticsParam.result: .string("cancelled"),
                AnalyticsParam.restoreOrigin: .string("paywall"),
            ])
        case .failed(let message):
            appState.analytics.log(AnalyticsEventName.paywallRestoreResult, [
                AnalyticsParam.result: .string("failed"),
                AnalyticsParam.restoreOrigin: .string("paywall"),
            ])
            appState.presentAlert(title: "Restore didn't complete", message: message)
        }
    }
}

#Preview {
    PaywallView(service: SimulatedPurchaseService())
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
