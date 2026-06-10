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

    // MARK: - Fonts

    /// SF Pro (system default sans).
    public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    /// SF Mono (`.monospaced`) for telemetry / numbers.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
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
}
