// AppState.swift — TapeScan
// Single source of truth for theme, feature flags and navigation.
// Ported 1:1 from the design's live "tweaks" model (accent / density / unit / lidar).

import SwiftUI
import Observation

/// Measurement unit system. Drives every value formatter in ``Theme``.
public enum MeasureUnit: String, CaseIterable, Identifiable, Sendable {
    case metric
    case imperial
    public var id: String { rawValue }
    /// Short title used in segmented controls ("Metric" / "Imperial").
    public var title: String { self == .metric ? "Metric" : "Imperial" }
}

/// Layout density. Scales radii and padding throughout the app.
/// Mirrors the design tokens: radius-scale 0.62/1/1.5, padding-scale 0.82/1/1.22.
public enum Density: String, CaseIterable, Identifiable, Sendable {
    case compact
    case regular
    case comfy
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// Radius scale factor — `r(n) = max(2, round(n * radiusScale))`.
    public var radiusScale: CGFloat {
        switch self {
        case .compact: return 0.62
        case .regular: return 1.0
        case .comfy:   return 1.5
        }
    }
    /// Padding / gap scale factor — `p(n) = round(n * paddingScale)`.
    public var paddingScale: CGFloat {
        switch self {
        case .compact: return 0.82
        case .regular: return 1.0
        case .comfy:   return 1.22
        }
    }
}

/// The five selectable accent colors (hex strings), in design order.
public enum AccentOption: String, CaseIterable, Identifiable, Sendable {
    case blue   = "#3B82F6"
    case cyan   = "#06B6D4"
    case violet = "#8B5CF6"
    case green  = "#22C55E"
    case amber  = "#F59E0B"

    public var id: String { rawValue }
    public var hex: String { rawValue }
    public var color: Color { Color(hex: rawValue) }

    /// Human-readable name surfaced in Settings.
    public var name: String {
        switch self {
        case .blue:   return "Blue"
        case .cyan:   return "Cyan"
        case .violet: return "Violet"
        case .green:  return "Green"
        case .amber:  return "Amber"
        }
    }
}

/// Top-level tabs in ``MainTabView`` (matches the design's bottom tab bar).
public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case measure
    case rooms
    case history
    case settings
    public var id: String { rawValue }

    /// SF Symbol-equivalent icon name in our ``Icon`` set.
    public var iconName: String {
        switch self {
        case .measure:  return "scan"
        case .rooms:    return "room"
        case .history:  return "ruler2"
        case .settings: return "gear"
        }
    }
    public var title: String {
        switch self {
        case .measure:  return "Measure"
        case .rooms:    return "Rooms"
        case .history:  return "History"
        case .settings: return "Settings"
        }
    }
}

/// Coarse app phase the ``RootView`` gates on: Auth → Onboarding → Main.
public enum AppPhase: Sendable {
    case auth
    case onboarding
    case main
}

/// A user-facing error/notice presented by the single global alert attached
/// in ``RootView``. Purchase, auth, sync, export, and AR-session failures all
/// surface through this — nothing fails silently.
public struct AppAlert: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var message: String

    public init(title: String, message: String) {
        self.id = UUID()
        self.title = title
        self.message = message
    }
}

/// Observable application state. Inject once at the root via
/// `.environment(appState)` and read with `@Environment(AppState.self)`.
///
/// All theming flows from here — mutating `accent`, `unit`, `density` or
/// `lidar` live-re-themes every screen that reads ``Theme``.
@MainActor
@Observable
public final class AppState {

    // MARK: - Branding
    /// Canonical product brand — the single source for every brand literal in
    /// the app (wordmark, Pro card, onboarding eyebrow, BrandField fallback).
    public static let defaultBrand = "TapeScan"
    /// Product brand string. Defaults to ``defaultBrand``; mutable so the
    /// DEBUG-only brand field in Settings can live-preview a reskin.
    public var brand: String = AppState.defaultBrand

    // MARK: - Theme tweaks (persisted)
    /// Selected accent option (drives `accent`, `accentSoft`, etc. in ``Theme``).
    public var accent: AccentOption = .blue {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: "accent") }
    }
    /// Convenience accessor for the accent color.
    public var accentColor: Color { accent.color }
    /// Convenience accessor for the accent display name.
    public var accentName: String { accent.name }

    /// Active measurement unit system.
    public var unit: MeasureUnit = .metric {
        didSet { UserDefaults.standard.set(unit.rawValue, forKey: "unit") }
    }
    /// Active layout density.
    public var density: Density = .regular {
        didSet { UserDefaults.standard.set(density.rawValue, forKey: "density") }
    }

    // MARK: - AR feature flags
    /// Whether the device LiDAR sensor is active. `false` => visual-inertial fallback.
    /// Drives precision badges, chip color/label and the fallback guidance banner.
    /// Session-only: real hardware capability is detected by the AR service (M4).
    public var lidar: Bool = true
    /// Snap newly placed points to existing ones within a small world-space
    /// threshold (closes polygons cleanly). Persisted user preference.
    public var snapEnabled: Bool = true {
        didSet { UserDefaults.standard.set(snapEnabled, forKey: "snapEnabled") }
    }

    // MARK: - Monetization
    /// Remaining free exports on the free tier (3 to start, persisted; the
    /// quota must survive relaunch or it is trivially bypassable).
    public var freeExportsLeft: Int = 3 {
        didSet { UserDefaults.standard.set(freeExportsLeft, forKey: "freeExportsLeft") }
    }
    /// Pro entitlement mirror for the UI. NEVER persisted here — set only from
    /// StoreKit entitlement checks (launch + Transaction.updates listener, M3).
    public var isPro: Bool = false

    // MARK: - Analytics
    /// The analytics sink (Firebase GA4 in release, no-op/console in tests/debug).
    /// `@ObservationIgnored` because it drives no view — it is a fire-and-forget
    /// service handle, mirroring ``SupabaseAuthService``'s non-reactive client.
    /// Default is the no-op impl so the app behaves identically before
    /// ``bootstrapped()`` swaps in the real service (and with zero SDK linked).
    @ObservationIgnored public var analytics: any AnalyticsService = NoopAnalyticsService()

    /// User opt-OUT of anonymous analytics collection. Default `false` =
    /// analytics ON (opt-out model; legitimate for first-party analytics with no
    /// IDFA/ATT). Persisted; the Settings toggle flips it. The `didSet` mirrors
    /// the flag into the live service and the matching user property so the
    /// choice takes effect immediately without a relaunch.
    public var analyticsOptOut: Bool = false {
        didSet {
            UserDefaults.standard.set(analyticsOptOut, forKey: "analyticsOptOut")
            analytics.setCollectionEnabled(!analyticsOptOut)
            analytics.setUserProperty(analyticsOptOut ? "true" : "false", for: .analyticsOptOut)
        }
    }

    // MARK: - Attribution
    /// The IAP entry-point attribution spine (pure value-type funnel memory).
    /// Owned here so AppState stays the single source of truth; the durable
    /// subset is JSON-persisted on every mutation via the `didSet`.
    public var attribution = AttributionTracker() {
        didSet { persistAttribution() }
    }

    /// JSON-encodes the durable subset of ``attribution`` to UserDefaults.
    /// `AttributionTracker.CodingKeys` excludes the session-only fields, so only
    /// the persistable state (lastSource / impressionsBySource / firstOpenAt /
    /// sessionCount) is written.
    private func persistAttribution() {
        if let data = try? JSONEncoder().encode(attribution) {
            UserDefaults.standard.set(data, forKey: "attribution")
        }
    }

    /// Convenience pass-throughs so call sites never reach into the struct.
    public var pendingPaywallSource: String? {
        get { attribution.pendingSource }
        set { attribution.pendingSource = newValue }
    }
    /// Sets both the live (pending) and persisted (last) paywall source — call
    /// IMMEDIATELY before presenting the paywall at each trigger site.
    public func beginPaywall(source: String) { attribution.beginPaywall(source: source) }
    /// Clears the session-only pending source on dismiss; leaves lastSource so
    /// out-of-band (Ask-to-Buy / renewal) approvals can still attribute.
    public func endPaywall() { attribution.endPaywall() }
    /// Stamps a core value-moment feature (first once per session, last each time).
    public func recordValueFeature(_ feature: String) { attribution.recordValueFeature(feature) }

    // MARK: - Error surface
    /// The single global alert (attached in ``RootView``). Set via
    /// ``presentAlert(title:message:)`` from any failure path.
    public var alert: AppAlert?

    /// Surfaces a user-facing failure through the global alert.
    public func presentAlert(title: String, message: String) {
        alert = AppAlert(title: title, message: message)
    }

    /// A transient, non-modal confirmation banner (e.g. "Measurement saved").
    /// Surfaced + auto-dismissed by ``RootView``; distinct from the modal ``alert``.
    public var notice: String?

    /// Shows a transient confirmation toast.
    public func presentNotice(_ message: String) { notice = message }

    // MARK: - Flow gating
    /// Set once the user has authenticated.
    public var isAuthenticated: Bool = false
    /// Set once the onboarding flow has completed (persisted).
    public var hasOnboarded: Bool = false {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: "hasOnboarded") }
    }
    /// Currently selected main tab.
    public var selectedTab: AppTab = .measure

    /// The device's real safe-area insets, captured once at the app root (where
    /// the normal view hierarchy reliably reports them) and read by modal covers.
    /// iOS 26 `.fullScreenCover` does NOT hand its content the device insets, so
    /// covers can't measure them locally — they read this instead and apply it
    /// via `.safeAreaInset` (see `EdgeInsets.coverManual`).
    public var safeAreaInsets: EdgeInsets = EdgeInsets()

    #if DEBUG
    /// DEBUG-only: when set, ``RootView`` auto-presents the paywall on launch with
    /// this context, for screenshot/UI verification. Never set in release.
    public var debugPaywallContext: PaywallContext?
    #endif

    /// Derived app phase the root view switches on. Accounts are OPTIONAL —
    /// auth never gates the app (Guideline 5.1.1); sign-in is offered as a
    /// dismissible sheet after onboarding and from Settings.
    public var phase: AppPhase {
        if !hasOnboarded { return .onboarding }
        return .main
    }

    /// Loads persisted settings. Assignments inside `init` do not fire
    /// `didSet`, so loading never echoes writes back to UserDefaults.
    public init() {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: "unit"), let v = MeasureUnit(rawValue: raw) { unit = v }
        if let raw = d.string(forKey: "accent"), let v = AccentOption(rawValue: raw) { accent = v }
        if let raw = d.string(forKey: "density"), let v = Density(rawValue: raw) { density = v }
        if d.object(forKey: "snapEnabled") != nil { snapEnabled = d.bool(forKey: "snapEnabled") }
        if d.object(forKey: "freeExportsLeft") != nil { freeExportsLeft = d.integer(forKey: "freeExportsLeft") }
        if d.object(forKey: "analyticsOptOut") != nil { analyticsOptOut = d.bool(forKey: "analyticsOptOut") }
        if let data = d.data(forKey: "attribution"),
           let t = try? JSONDecoder().decode(AttributionTracker.self, from: data) {
            attribution = t
        }
        hasOnboarded = d.bool(forKey: "hasOnboarded")
    }

    /// Builds the root state, applying DEBUG-only launch arguments used for
    /// UI/screenshot verification. In release builds (or with no args) this is
    /// byte-identical to `AppState()`, so the canonical flow is never altered.
    ///
    /// Supported args: `-uiPhase auth|onboarding|main`, `-uiTab measure|rooms|
    /// history|settings`, `-uiFreeExports <Int>`, `-uiPro 1`.
    public static func bootstrapped() -> AppState {
        let state = AppState()
        // Wire the production analytics service. This only stores a handle —
        // FirebaseAnalyticsService.init() touches NO Firebase API; collection is
        // toggled later from the root .task and the `analyticsOptOut` didSet.
        state.analytics = FirebaseAnalyticsService.shared
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        // DEBUG-only: route analytics to a console-logging sink for verification,
        // consistent with the other -ui* launch-argument plumbing.
        if value("-uiAnalytics") == "console" {
            state.analytics = DebugLoggingAnalyticsService()
        }
        switch value("-uiPhase") {
        case "onboarding": state.hasOnboarded = false
        case "main":       state.hasOnboarded = true
        default: break
        }
        if let tab = value("-uiTab").flatMap(AppTab.init(rawValue:)) { state.selectedTab = tab }
        if let n = value("-uiFreeExports").flatMap(Int.init) { state.freeExportsLeft = n }
        if value("-uiPro") == "1" { state.isPro = true }
        switch value("-uiPaywall") {
        case "exhausted":
            state.debugPaywallContext = .quotaExhausted
            state.beginPaywall(source: PaywallSource.debug)
        case "proactive":
            state.debugPaywallContext = .proactive(freeExportsLeft: state.freeExportsLeft)
            state.beginPaywall(source: PaywallSource.debug)
        default: break
        }
        #endif
        return state
    }

    // MARK: - Intents
    /// Mirrors a successful sign-in (sync becomes available).
    public func completeAuth() { isAuthenticated = true }
    /// Marks onboarding complete (advances Onboarding → Main).
    public func completeOnboarding() { hasOnboarded = true }
    /// Clears the signed-in mirror. Local data and onboarding state stay —
    /// signing out never costs the user anything.
    public func signOut() {
        isAuthenticated = false
    }
}


