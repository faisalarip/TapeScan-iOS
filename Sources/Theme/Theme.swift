// Theme.swift — the design token system.
//
// `Theme` is BOTH:
//   • a namespace of FIXED tokens (colors, fonts) accessed statically:
//        Theme.ink, Theme.glass, Theme.sans(15, weight: .semibold)
//   • a live-derived snapshot of the tweakable tokens (accent / density / unit /
//     lidar) that you read from the environment:
//        @Environment(\.theme) private var theme
//        theme.accent, theme.r(16), theme.precisionBadge
//
// `Theme.fallback` is an IMMUTABLE default that stand-alone atoms / #Previews
// resolve accent from when no explicit value is given. It is never mutated, so
// theme installation has no side effects during view evaluation. RootView
// installs the live theme into the environment via `.installTheme(...)`.

import SwiftUI
import UIKit

public struct Theme: Equatable, Sendable {

    // MARK: - Tweakable tokens (instance)
    public var accent: Color
    public var accentName: String
    public var unit: MeasureUnit
    public var density: Density
    public var lidar: Bool

    public init(accent: Color = AccentOption.blue.color,
                accentName: String = AccentOption.blue.name,
                unit: MeasureUnit = .metric,
                density: Density = .regular,
                lidar: Bool = true) {
        self.accent = accent
        self.accentName = accentName
        self.unit = unit
        self.density = density
        self.lidar = lidar
    }

    /// Builds a theme snapshot from the live application state.
    @MainActor
    public init(_ state: AppState) {
        self.init(accent: state.accentColor,
                  accentName: state.accentName,
                  unit: state.unit,
                  density: state.density,
                  lidar: state.lidar)
    }

    // MARK: - Derived accent tints
    /// accent @ 0.16 — the soft fill used behind icons / selected rows.
    public var accentSoft: Color { accent.withA(0.16) }
    /// accent @ 0.90 — solid-ish chip / line fill.
    public var accentLine: Color { accent.withA(0.90) }

    // MARK: - Density scalers
    /// Radius: `max(2, round(n * radiusScale))`.
    public func r(_ n: CGFloat) -> CGFloat {
        max(2, (n * density.radiusScale).rounded())
    }
    /// Padding / gap: `round(n * paddingScale)`.
    public func p(_ n: CGFloat) -> CGFloat {
        (n * density.paddingScale).rounded()
    }

    // MARK: - LiDAR-derived strings (from the HTML reference)
    /// "4 mm" (LiDAR) vs "2 cm" (fallback) — bare precision used in telemetry.
    public var precision: String { lidar ? "4 mm" : "2 cm" }
    /// "±4 mm" (LiDAR) vs "±2 cm" (fallback) — badge form.
    public var precisionBadge: String { lidar ? "±4 mm" : "±2 cm" }

    // MARK: - Immutable fallback
    /// An immutable default theme. Atoms resolve accent/density from this only
    /// when constructed without an explicit value (effectively just #Previews —
    /// every production call site passes an explicit accent). Because it never
    /// mutates, installing the live theme is a pure environment write with no
    /// view-evaluation side effects.
    public static let fallback = Theme()

    // MARK: - Fixed surface tokens (static — never change with tweaks)

    /// Screen background `#0c0d10`.
    public static let screenBG = Color(hex: "#0c0d10")
    /// Camera feed background `#0b0c0e`.
    public static let cameraBG = Color(hex: "#0b0c0e")
    /// Glass surface fill `rgba(18,20,24,0.58)`.
    public static let glass = Color(.sRGB, red: 18/255, green: 20/255, blue: 24/255, opacity: 0.58)
    /// 1px glass border color `rgba(255,255,255,0.12)`.
    public static let glassBorder = Color.white.opacity(0.12)
    /// Deck surface `rgba(13,14,17,0.92)`.
    public static let deck = Color(.sRGB, red: 13/255, green: 14/255, blue: 17/255, opacity: 0.92)

    /// Ink (primary text) — white.
    public static let ink = Color.white
    /// Ink2 (secondary text) — white @ 0.62.
    public static let ink2 = Color.white.opacity(0.62)
    /// Ink3 (tertiary / muted) — white @ 0.38.
    public static let ink3 = Color.white.opacity(0.38)

    /// Amber accent `#f59e0b` (fallback / quota / warnings).
    public static let amber = Color(hex: "#f59e0b")
    /// Tracking-success green `#34d399`.
    public static let successGreen = Color(hex: "#34d399")
    /// iOS system green `#34c759` (toggles / save tags).
    public static let iosGreen = Color(hex: "#34c759")
    /// Purple `#8b5cf6` (volume icon tint).
    public static let purple = Color(hex: "#8b5cf6")

    // MARK: - Fonts (Dynamic Type aware)

    /// SF Pro (system default sans), scaling with the user's text size: the
    /// design's point sizes stay exact at the default setting and scale via
    /// UIFontMetrics anchored to the nearest semantic text style.
    public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaledSize(size), weight: weight, design: .default)
    }
    /// SF Mono (`.monospaced`) for telemetry / numbers, scaling likewise.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaledSize(size), weight: weight, design: .monospaced)
    }

    /// Design pt → user-scaled pt. SwiftUI re-evaluates bodies on text-size
    /// changes, so fonts rebuilt here track the live setting. Mapping table:
    /// ≤11 caption2 · ≤13 footnote · ≤15 subheadline · ≤17 body · ≤20 title3
    /// · ≤24 title2 · ≤30 title · larger largeTitle.
    private static func scaledSize(_ size: CGFloat) -> CGFloat {
        let style: UIFont.TextStyle = switch size {
        case ..<11.5:  .caption2
        case ..<13.5:  .footnote
        case ..<15.75: .subheadline
        case ..<18:    .body
        case ..<21:    .title3
        case ..<25:    .title2
        case ..<31:    .title1
        default:       .largeTitle
        }
        return UIFontMetrics(forTextStyle: style).scaledValue(for: size)
    }
}

// MARK: - Environment plumbing

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme()
}

public extension EnvironmentValues {
    /// The live design theme. Read with `@Environment(\.theme) private var theme`.
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

public extension View {
    /// Installs a live ``Theme`` into the environment. This is a pure environment
    /// write — no static mutation, so it is safe to call during view evaluation.
    func installTheme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
    }

    /// Lays out modal-cover content inside the device safe area using `insets`,
    /// then opts the content out of the cover's own safe area.
    ///
    /// Why this exists: on iOS 26 a `.fullScreenCover` does NOT propagate the
    /// top/bottom safe-area insets to its SwiftUI content — the content lands at
    /// y = 0 under the status bar / Dynamic Island even with no `.ignoresSafeArea()`,
    /// and a `GeometryReader` *inside* the cover reports `inset.top == 0`, so the
    /// cover can't measure them locally. Pass the REAL insets captured at the app
    /// root (``AppState/safeAreaInsets``); the content opts out of the cover's safe
    /// area and pads by them for one identical, correct result on iOS 17 through 26.
    /// Pair with a full-bleed background sibling:
    /// `ZStack { Theme.screenBG.ignoresSafeArea(); content.coverSafeAreaPadding(insets) }`.
    func coverSafeAreaPadding(_ insets: EdgeInsets) -> some View {
        // iOS 17/18 `.fullScreenCover` applies the device safe area to its content,
        // so no manual inset is needed there. iOS 26 (Apple's year-based renumber
        // directly after 18 — there are NO versions in between, so this boundary is
        // exact, not a guess) does NOT: its cover content lays out from y=0 under
        // the status bar.
        //
        // On 26+, offset with REAL fixed-height spacer views (not `.padding`, not
        // `.ignoresSafeArea` — both composed unreliably on physical devices,
        // rendering correctly in the simulator while silently collapsing on device).
        // A `Color.clear` with a fixed `.frame(height:)` is a concrete subview the
        // stack MUST allocate space for; nothing in the safe-area system can absorb
        // it. `insets` are the device's real values captured at the app root.
        let needsManualInset: Bool
        if #available(iOS 26, *) { needsManualInset = true } else { needsManualInset = false }
        print("🔵SA coverSafeAreaPadding: insets top \(insets.top) / bottom \(insets.bottom) · needsManual=\(needsManualInset) · topSpacer=\(needsManualInset ? insets.top : 0)")
        return VStack(spacing: 0) {
            if needsManualInset {
                Color.clear.frame(height: insets.top)
            }
            self
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            if needsManualInset {
                Color.clear.frame(height: insets.bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The device's real safe-area insets, read from the key window. Capture this in
/// the normal hierarchy at a reliable time (e.g. RootView `onAppear` / scene
/// activation) and stash on ``AppState`` for modal covers to read — see
/// ``SwiftUICore/View/coverSafeAreaPadding(_:)``. Reading it at a cover's own body
/// time is unreliable (the window/scene may not be settled yet on device).
public enum WindowSafeArea {
    @MainActor
    public static var insets: EdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        let keyWindow = windows.first(where: \.isKeyWindow)
        let inset = keyWindow?.safeAreaInsets ?? .zero
        print("🔵SA WindowSafeArea.insets: scenes=\(scenes.count) windows=\(windows.count) keyWindow=\(keyWindow != nil) → top \(inset.top) / bottom \(inset.bottom)")
        return EdgeInsets(top: inset.top, leading: inset.left,
                          bottom: inset.bottom, trailing: inset.right)
    }
}
