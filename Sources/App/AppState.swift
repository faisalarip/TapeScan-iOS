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

    // MARK: - Theme tweaks
    /// Selected accent option (drives `accent`, `accentSoft`, etc. in ``Theme``).
    public var accent: AccentOption = .blue
    /// Convenience accessor for the accent color.
    public var accentColor: Color { accent.color }
    /// Convenience accessor for the accent display name.
    public var accentName: String { accent.name }

    /// Active measurement unit system.
    public var unit: MeasureUnit = .metric
    /// Active layout density.
    public var density: Density = .regular

    // MARK: - AR feature flags
    /// Whether the device LiDAR sensor is active. `false` => visual-inertial fallback.
    /// Drives precision badges, chip color/label and the fallback guidance banner.
    public var lidar: Bool = true

    // MARK: - Monetization
    /// Remaining free exports on the free tier (design starts at 2 of 3 used → 1 left,
    /// but the spec's default is 2; kept configurable here).
    public var freeExportsLeft: Int = 2
    /// Pro entitlement. A successful purchase or restore flips this true, which
    /// unlocks export (bypassing the free-export quota) everywhere it is gated.
    public var isPro: Bool = false

    /// Grants the Pro entitlement after a successful purchase / restore.
    public func grantPro() { isPro = true }

    // MARK: - Flow gating
    /// Set once the user has authenticated.
    public var isAuthenticated: Bool = false
    /// Set once the onboarding flow has completed.
    public var hasOnboarded: Bool = false
    /// Currently selected main tab.
    public var selectedTab: AppTab = .measure

    #if DEBUG
    /// DEBUG-only: when set, ``RootView`` auto-presents the paywall on launch with
    /// this context, for screenshot/UI verification. Never set in release.
    public var debugPaywallContext: PaywallContext?
    #endif

    /// Derived app phase the root view switches on.
    public var phase: AppPhase {
        if !isAuthenticated { return .auth }
        if !hasOnboarded { return .onboarding }
        return .main
    }

    public init() {}

    /// Builds the root state, applying DEBUG-only launch arguments used for
    /// UI/screenshot verification. In release builds (or with no args) this is
    /// byte-identical to `AppState()`, so the canonical flow is never altered.
    ///
    /// Supported args: `-uiPhase auth|onboarding|main`, `-uiTab measure|rooms|
    /// history|settings`, `-uiFreeExports <Int>`, `-uiPro 1`.
    public static func bootstrapped() -> AppState {
        let state = AppState()
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        switch value("-uiPhase") {
        case "onboarding": state.isAuthenticated = true
        case "main":       state.isAuthenticated = true; state.hasOnboarded = true
        default: break
        }
        if let tab = value("-uiTab").flatMap(AppTab.init(rawValue:)) { state.selectedTab = tab }
        if let n = value("-uiFreeExports").flatMap(Int.init) { state.freeExportsLeft = n }
        if value("-uiPro") == "1" { state.isPro = true }
        switch value("-uiPaywall") {
        case "exhausted": state.debugPaywallContext = .quotaExhausted
        case "proactive": state.debugPaywallContext = .proactive(freeExportsLeft: state.freeExportsLeft)
        default: break
        }
        #endif
        return state
    }

    // MARK: - Intents
    /// Marks the user as signed in (advances Auth → Onboarding).
    public func completeAuth() { isAuthenticated = true }
    /// Marks onboarding complete (advances Onboarding → Main).
    public func completeOnboarding() { hasOnboarded = true }
    /// Signs out and resets the flow back to Auth.
    public func signOut() {
        isAuthenticated = false
        hasOnboarded = false
        selectedTab = .measure
    }
}
