// GlassCard.swift — frosted glass container + primary action button.

import SwiftUI

/// A frosted glass surface card. Wraps arbitrary content with the design's
/// glass fill, hairline border, density-scaled corner radius and soft shadow.
public struct GlassCard<Content: View>: View {
    @Environment(\.theme) private var theme
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let fill: Color
    private let content: Content

    /// - Parameters:
    ///   - cornerRadius: base radius (passed through `theme.r(_:)`). Default 24.
    ///   - padding: base inner padding (passed through `theme.p(_:)`). Default 16.
    ///   - fill: surface fill. Default the design's bottom-deck glass.
    public init(cornerRadius: CGFloat = 24,
                padding: CGFloat = 16,
                fill: Color = Color(.sRGB, red: 16/255, green: 18/255, blue: 22/255, opacity: 0.72),
                @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.fill = fill
        self.content = content()
    }

    public var body: some View {
        content
            .padding(theme.p(padding))
            .background(
                RoundedRectangle(cornerRadius: theme.r(cornerRadius), style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.r(cornerRadius), style: .continuous)
                            .fill(fill)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(cornerRadius), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 25, y: 16)
    }
}

/// The full-width primary action button: solid accent, optional leading glyph,
/// density-scaled radius, accent glow.
public struct PrimaryButton: View {
    @Environment(\.theme) private var theme
    private let title: String
    private let icon: String?
    private let action: () -> Void

    /// - Parameters:
    ///   - title: button label.
    ///   - icon: optional leading icon name.
    ///   - action: tap handler.
    public init(title: String, icon: String? = nil, action: @escaping () -> Void = {}) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let icon {
                    Icon(icon, size: 19, weight: 2.2, color: .white)
                }
                Text(title)
                    .font(Theme.sans(16, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: theme.r(16), style: .continuous)
                    .fill(theme.accent.withA(0.96))
            )
            .shadow(color: theme.accent.withA(0.4), radius: 13, y: 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Theme.screenBG
        VStack(spacing: 20) {
            GlassCard {
                Text("Glass card")
                    .font(Theme.sans(17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
            }
            PrimaryButton(title: "Start Measuring", icon: "ruler2")
        }
        .padding()
    }
    .environment(\.theme, Theme(accent: AccentOption.blue.color))
    .frame(width: 402, height: 400)
}
