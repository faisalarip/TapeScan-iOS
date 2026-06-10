// Shutter.swift — round capture button + secondary circle button.

import SwiftUI

/// The primary capture / shutter button: white ring around an accent disc with
/// a centered glyph and accent glow.
public struct Shutter: View {
    private let accent: Color
    private let size: CGFloat
    private let icon: String
    private let action: () -> Void

    /// - Parameters:
    ///   - accent: disc + glow tint. Defaults to live theme accent.
    ///   - size: outer diameter. Default 70.
    ///   - icon: centered glyph name. Default `"plus"`.
    ///   - action: tap handler. Default no-op.
    public init(accent: Color? = nil,
                size: CGFloat = 70,
                icon: String = "plus",
                action: @escaping () -> Void = {}) {
        self.accent = accent ?? Theme.fallback.accent
        self.size = size
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 3)
                    .frame(width: size, height: size)
                Circle()
                    .fill(accent)
                    .frame(width: size - 14, height: size - 14)
                    .shadow(color: accent.withA(0.6), radius: 10)
                Icon(icon, size: size * 0.34, weight: 2.4, color: .white)
            }
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
    }
}

/// Secondary round glass button (undo / check / etc.).
public struct CircleButton: View {
    private let accent: Color
    private let icon: String
    private let size: CGFloat
    private let solid: Bool
    private let action: () -> Void

    public init(accent: Color? = nil,
                icon: String,
                size: CGFloat = 44,
                solid: Bool = false,
                action: @escaping () -> Void = {}) {
        self.accent = accent ?? Theme.fallback.accent
        self.icon = icon
        self.size = size
        self.solid = solid
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Icon(icon, size: size * 0.42, weight: 1.9, color: .white)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(solid ? Color.white.opacity(0.12)
                                        : Color(.sRGB, red: 10/255, green: 12/255, blue: 15/255, opacity: 0.55))
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Theme.cameraBG
        HStack(spacing: 24) {
            CircleButton(accent: AccentOption.blue.color, icon: "undo")
            Shutter(accent: AccentOption.blue.color)
            CircleButton(accent: AccentOption.blue.color, icon: "check")
        }
    }
    .frame(width: 402, height: 200)
}
