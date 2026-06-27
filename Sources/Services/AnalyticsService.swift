// AnalyticsService.swift — the analytics seam (GA4 / Firebase, attribution).
//
// This file is the single seam through which the whole app emits product
// analytics. It mirrors `PurchaseService.swift` exactly in shape: a small,
// StoreKit-free (here: Firebase-free) value model + a `@MainActor` protocol,
// then a production implementation (`FirebaseAnalyticsService`) and
// preview/test implementations (`NoopAnalyticsService`,
// `DebugLoggingAnalyticsService`).
//
// DESIGN GOAL — measure WHICH feature / entry point drives IAP conversions
// without leaking PII and without coupling the app to Firebase at compile time.
//
// HARD CONSTRAINTS enforced here:
//  • The project MUST compile with ZERO Firebase SDK present. Every Firebase
//    `import`, type, and call is wrapped in `#if canImport(FirebaseAnalytics)` /
//    `#if canImport(FirebaseCore)` with a no-op `#else`. The owner adds the SPM
//    package + GoogleService-Info.plist later to activate it; until then this is
//    a silent no-op.
//  • NO IDFA / no AdSupport / no ATT prompt. We never call `setUserID`, never
//    log emails, raw Supabase ids, room names, file paths, or free-text — only
//    the closed `AnalyticsUserProperty` vocabulary and bucketed param strings.
//  • Opt-out model: collection defaults ON (legitimate first-party analytics
//    with no IDFA/ATT); a Settings toggle flips
//    `Analytics.setAnalyticsCollectionEnabled` via `setCollectionEnabled`.
//
// The TYPED VOCABULARY (event names, param keys, paywall sources, plan-kind
// mapping) lives OUTSIDE every `#if` so both build configurations — with and
// without the SDK — compile identically and the taxonomy is compile-checked
// (names cannot drift across call sites).

import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

// MARK: - Pure event model

/// A single analytics event: a stable `name` (from `AnalyticsEventName`) plus a
/// small bag of typed parameters. Deliberately Firebase-free and `Sendable` so
/// the funnel logic and tests never touch the SDK.
public struct AnalyticsEvent: Equatable, Sendable {
    public let name: String
    public let params: [String: AnalyticsValue]

    public init(_ name: String, _ params: [String: AnalyticsValue] = [:]) {
        self.name = name
        self.params = params
    }
}

/// The closed set of parameter value kinds we ever emit. Closing the type here
/// (rather than `Any`) is what keeps the seam PII-safe and unit-testable: there
/// is no slot for an arbitrary object, and `Equatable` makes events assertable.
public enum AnalyticsValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

/// The closed set of GA4 user properties we set. Free-text is impossible by
/// construction — there is no `.custom(String)` case — which enforces the
/// no-PII rule at the type level (no emails / raw user ids / room names).
public enum AnalyticsUserProperty: String, Sendable {
    case isPro = "is_pro"
    case planKind = "plan_kind_owned"
    case lidar = "lidar"
    case onboardingCompleted = "onboarding_completed"
    case analyticsOptOut = "analytics_opt_out"
    case acquisitionSourceFirst = "acquisition_source_first"
}

// MARK: - Service seam

/// The analytics sink. `@MainActor AnyObject` (NOT `Observable`) — it drives no
/// view, so unlike `PurchaseService` it does not need to be observed; this
/// mirrors the non-reactive `AuthService` client. Inject one instance via
/// `AppState.analytics`.
///
/// The low-level `log(_:)` mirrors `PurchaseService.purchase` (one sink the
/// whole app funnels through); the `log(_:_:)` convenience on the protocol
/// extension is the everyday call site.
@MainActor
public protocol AnalyticsService: AnyObject {
    /// True only when the SDK is present AND collection is enabled. Call sites
    /// don't need to check this — `log` no-ops when false — but it's exposed for
    /// diagnostics and the debug overlay.
    var isEnabled: Bool { get }

    /// Idempotent launch hook. Call ONCE from the root `.task`, AFTER
    /// `FirebaseApp.configure()`, before any `log`. Applies the persisted
    /// collection preference. Safe to call when no SDK is linked (no-op).
    func start(collectionEnabled: Bool)

    /// Flip GA4 collection on/off (the Settings opt-out toggle). Bridges to
    /// `Analytics.setAnalyticsCollectionEnabled` when the SDK is present.
    func setCollectionEnabled(_ enabled: Bool)

    /// Emit one event. No-ops when `!isEnabled`.
    func log(_ event: AnalyticsEvent)

    /// Set (or clear, when `value == nil`) a closed-vocabulary user property.
    func setUserProperty(_ value: String?, for property: AnalyticsUserProperty)
}

public extension AnalyticsService {
    /// Ergonomic call site: `analytics.log(AnalyticsEventName.appOpen, [...])`.
    func log(_ name: String, _ params: [String: AnalyticsValue] = [:]) {
        log(AnalyticsEvent(name, params))
    }
}

// MARK: - Firebase parameter bridge (only when the SDK is linked)

#if canImport(FirebaseAnalytics)
extension Dictionary where Key == String, Value == AnalyticsValue {
    /// Lower our typed values into the `[String: Any]` Firebase expects.
    /// Numbers and bools become `NSNumber` (GA4 logs bools as 0/1); strings stay
    /// strings. Compiled ONLY when the SDK is present so the no-SDK build never
    /// references Firebase or `NSNumber` bridging semantics it doesn't need.
    var firebaseParameters: [String: Any] {
        var out: [String: Any] = [:]
        out.reserveCapacity(count)
        for (key, value) in self {
            switch value {
            case .string(let s): out[key] = s
            case .int(let i):    out[key] = NSNumber(value: i)
            case .double(let d): out[key] = NSNumber(value: d)
            case .bool(let b):   out[key] = NSNumber(value: b)
            }
        }
        return out
    }
}
#endif

// MARK: - Production implementation (Firebase GA4)

/// The shipping analytics backend. Honest-fallback by design: when the Firebase
/// SDK is NOT linked, every method compiles to a no-op and `sdkAvailable` is
/// `false`, so the app behaves exactly as if analytics were turned off (mirrors
/// the `SupabaseConfig.isConfigured` posture — never fakes success).
///
/// IMPORTANT: `init()` never touches Firebase. `FirebaseApp.configure()` is
/// owned by the App entry point; this object only starts collection and logs
/// once `start(collectionEnabled:)` is called from the root `.task`.
@MainActor
public final class FirebaseAnalyticsService: AnalyticsService {
    public static let shared = FirebaseAnalyticsService()

    /// Stored collection preference (mirror of `!AppState.analyticsOptOut`).
    /// We keep our own copy so `isEnabled` is answerable without querying the
    /// SDK, and so the no-SDK build still reports a coherent state.
    private var collectionEnabled = true

    private init() {}

    /// True when the Firebase Analytics SDK is compiled in. The owner flips this
    /// to `true` simply by adding the SPM package — no code change.
    public var sdkAvailable: Bool {
        #if canImport(FirebaseAnalytics)
        return true
        #else
        return false
        #endif
    }

    /// We only emit when the SDK is present AND the user hasn't opted out.
    public var isEnabled: Bool { sdkAvailable && collectionEnabled }

    public func start(collectionEnabled: Bool) {
        // Idempotent: just (re)apply the preference. `FirebaseApp.configure()`
        // has already run in the App `init` by the time this is called.
        setCollectionEnabled(collectionEnabled)
    }

    public func setCollectionEnabled(_ enabled: Bool) {
        collectionEnabled = enabled
        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(enabled)
        #endif
    }

    public func log(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.name, parameters: event.params.firebaseParameters)
        #endif
    }

    public func setUserProperty(_ value: String?, for property: AnalyticsUserProperty) {
        // User properties are persistent dimensions; we still gate them on
        // collection so opt-out users leave no profile behind.
        guard isEnabled else { return }
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: property.rawValue)
        #endif
    }
}

// MARK: - No-op implementation (default before the SDK is wired)

/// The default `AppState.analytics` value: does nothing, reports disabled. Lets
/// the entire app run (and tests / previews execute) with zero analytics side
/// effects, exactly like `SimulatedPurchaseService` is the preview backend.
@MainActor
public final class NoopAnalyticsService: AnalyticsService {
    public init() {}
    public var isEnabled: Bool { false }
    public func start(collectionEnabled: Bool) {}
    public func setCollectionEnabled(_ enabled: Bool) {}
    public func log(_ event: AnalyticsEvent) {}
    public func setUserProperty(_ value: String?, for property: AnalyticsUserProperty) {}
}

#if DEBUG
// MARK: - Debug implementation (console + capture for tests)

/// DEBUG-only sink that records every event in memory and prints it. Wired in
/// via the `-uiAnalytics console` launch argument (see `AppState.bootstrapped`),
/// and used by unit tests to assert the funnel fires the right events with the
/// right params. Respects `setCollectionEnabled(false)` like the real service.
@MainActor
public final class DebugLoggingAnalyticsService: AnalyticsService {
    /// Every event passed to `log` while enabled, in order — assert against this.
    public private(set) var recorded: [AnalyticsEvent] = []
    /// Every user property set while enabled, in order (for test assertions).
    public private(set) var userProperties: [(property: AnalyticsUserProperty, value: String?)] = []

    private var collectionEnabled: Bool

    public init(collectionEnabled: Bool = true) {
        self.collectionEnabled = collectionEnabled
    }

    public var isEnabled: Bool { collectionEnabled }

    public func start(collectionEnabled: Bool) {
        self.collectionEnabled = collectionEnabled
    }

    public func setCollectionEnabled(_ enabled: Bool) {
        collectionEnabled = enabled
    }

    public func log(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        recorded.append(event)
        print("📊 analytics: \(event.name) \(event.params)")
    }

    public func setUserProperty(_ value: String?, for property: AnalyticsUserProperty) {
        guard isEnabled else { return }
        userProperties.append((property, value))
        print("📊 analytics user_property: \(property.rawValue) = \(value ?? "nil")")
    }
}
#endif

// MARK: - Typed vocabulary (OUTSIDE every #if — both build configs compile it)

/// GA4 event names. Reserved GA4 names (`screen_view`, `purchase`) are spelled
/// exactly so they light up Firebase's built-in reports; the rest are custom
/// funnel events. Centralizing them here makes names impossible to mistype at a
/// call site and keeps the taxonomy reviewable in one place.
public enum AnalyticsEventName {
    public static let appOpen = "app_open"
    public static let screenView = "screen_view"
    public static let onboardingWelcomeCompleted = "onboarding_welcome_completed"
    public static let onboardingPermissionCompleted = "onboarding_permission_completed"
    public static let onboardingCompleted = "onboarding_completed"
    public static let measurePointPlaced = "measure_point_placed"
    public static let measureFinished = "measure_finished"
    public static let roomScanStarted = "room_scan_started"
    public static let roomScanFinished = "room_scan_finished"
    public static let roomSaved = "room_saved"
    public static let floorPlanEditOpened = "floor_plan_edit_opened"
    public static let floorPlanSaved = "floor_plan_saved"
    public static let exportScreenOpened = "export_screen_opened"
    public static let exportGenerated = "export_generated"
    public static let exportShared = "export_shared"
    public static let paywallView = "paywall_view"
    public static let paywallPlanSelected = "paywall_plan_selected"
    public static let paywallPurchaseStart = "paywall_purchase_start"
    public static let paywallPurchaseSuccess = "paywall_purchase_success"
    /// GA4 RESERVED revenue event — fired ALONGSIDE `paywallPurchaseSuccess`
    /// only on the live paywall success path (never from the source-less
    /// StoreKit listener, to avoid double-counting new-conversion revenue).
    public static let purchase = "purchase"
    public static let paywallPurchaseCancelled = "paywall_purchase_cancelled"
    public static let paywallPurchasePending = "paywall_purchase_pending"
    public static let paywallPurchaseFailed = "paywall_purchase_failed"
    public static let paywallRestoreResult = "paywall_restore_result"
    public static let subscriptionStatusChange = "subscription_status_change"
}

/// GA4 event parameter keys. Reserved GA4 keys (`value`, `currency`,
/// `transaction_id`, `items`, `screen_name`) are spelled exactly. Everything
/// else is registered by the owner as a custom dimension/metric in GA4 Admin.
public enum AnalyticsParam {
    public static let paywallSource = "paywall_source"
    public static let paywallContext = "paywall_context"
    public static let freeExportsLeft = "free_exports_left"
    public static let isAuthenticated = "is_authenticated"
    public static let touchpointCount = "touchpoint_count"
    public static let firstValueFeature = "first_value_feature"
    public static let lastValueFeature = "last_value_feature"
    public static let productId = "product_id"
    public static let planKind = "plan_kind"
    public static let hasTrial = "has_trial"
    public static let requiresSignin = "requires_signin"
    public static let failureReason = "failure_reason"
    public static let result = "result"
    public static let restoreOrigin = "restore_origin"
    public static let changeType = "change_type"
    public static let source = "source"
    public static let screenName = "screen_name"
    public static let granted = "granted"
    public static let hit = "hit"
    public static let mode = "mode"
    public static let wallCount = "wall_count"
    public static let formatsCount = "formats_count"
    public static let sessionsToConvert = "sessions_to_convert"
    public static let timeToConvertBucket = "time_to_convert_bucket"
    public static let isPro = "is_pro"
    public static let lidar = "lidar"
    // GA4 reserved revenue keys (purchase event):
    public static let value = "value"
    public static let currency = "currency"
    public static let transactionId = "transaction_id"
    public static let items = "items"
}

/// The closed set of paywall entry points — the LAST-TOUCH attribution spine.
/// Exactly four raw strings; each trigger site calls `appState.beginPaywall`
/// with one of these immediately before presenting the paywall. The two
/// ExportView sites share one `showPaywall` binding, so they MUST stamp
/// distinct sources here — telling those two apart is the whole point.
public enum PaywallSource {
    public static let settingsUpsell = "settings_upsell"
    public static let exportQuotaMeter = "export_quota_meter"
    public static let exportCtaLocked = "export_cta_locked"
    public static let debug = "debug"
}

/// GA4 `screen_view` screen names for the non-tab full-screen / modal roots. Tab
/// screens reuse `AppTab.rawValue`; these cover the conversion-path screens so
/// Firebase's screen reports aren't missing Export / Paywall / Scan / Editor.
public enum ScreenName {
    public static let export = "export"
    public static let paywall = "paywall"
    public static let roomScan = "room_scan"
    public static let floorPlanEditor = "floor_plan_editor"
}

/// Maps a StoreKit product id to a low-cardinality plan kind for GA4. Pure and
/// Firebase-free (like `ProductMapping`) so it's trivially unit-testable and
/// usable from both the live paywall and the source-less StoreKit listener.
public enum PlanKind {
    public static func from(productID: String) -> String {
        switch productID {
        case ProductMapping.monthlyID:  return "monthly"
        case ProductMapping.annualID:   return "annual"
        case ProductMapping.lifetimeID: return "lifetime"
        default:                        return "unknown"
        }
    }
}
