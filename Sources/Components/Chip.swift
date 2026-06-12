// Chip.swift — glass pill chip + status dot + fallback banner.

import SwiftUI

/// A small blinking / steady status dot with a colored glow.
public struct StatusDot: View {
    private let color: Color
    private let blink: Bool

    public init(color: Color, blink: Bool = false) {
        self.color = color
        self.blink = blink
    }

    @State private var on = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color, radius: 3)
            .opacity(blink ? (on ? 1 : 0.35) : 1)
            .onAppear {
                guard blink, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    on = false
                }
            }
    }
}

/// Glass chip / pill. `active` fills with accent; otherwise dark glass.
/// Compose content (icon + text + dot) into the trailing `content` builder.
public struct Chip<Content: View>: View {
    private let accent: Color
    private let active: Bool
    private let mono: Bool
    private let height: CGFloat
    private let fontSize: CGFloat
    private let content: Content

    /// - Parameters:
    ///   - accent: fill tint when `active`. Defaults to live theme accent.
    ///   - active: solid accent fill (white text) vs dark glass. Default false.
    ///   - mono: use the mono font. Default false.
    ///   - height: pill height. Default 30.
    ///   - fontSize: label size. Default 12.
    public init(accent: Color? = nil,
                active: Bool = false,
                mono: Bool = false,
                height: CGFloat = 30,
                fontSize: CGFloat = 12,
                @ViewBuilder content: () -> Content) {
        self.accent = accent ?? Theme.fallback.accent
        self.active = active
        self.mono = mono
        self.height = height
        self.fontSize = fontSize
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 6) {
            content
        }
        .font(mono ? Theme.mono(fontSize, weight: .semibold)
                   : Theme.sans(fontSize, weight: .semibold))
        .tracking(0.2)
        .foregroundStyle(active ? Color.white : Color.white.opacity(0.82))
        .padding(.horizontal, 11)
        .frame(height: height)
        .background(
            Capsule().fill(active ? accent.withA(0.9) : Theme.glass)
        )
        .overlay(
            Capsule().strokeBorder(
                active ? accent.withA(0.4) : Color.white.opacity(0.13),
                lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
    }
}

/// No-LiDAR fallback banner: amber glass pill announcing visual-inertial tracking.
public struct FallbackBanner: View {
    private let amber: Color

    public init(amber: Color = Theme.amber) { self.amber = amber }

    public var body: some View {
        HStack(spacing: 7) {
            StatusDot(color: amber, blink: true)
            Text("Visual-inertial tracking · LiDAR not detected")
        }
        .font(Theme.sans(11.5, weight: .semibold))
        .tracking(0.1)
        .foregroundStyle(Color.white.opacity(0.9))
        .padding(.horizontal, 11)
        .frame(height: 26)
        .background(Capsule().fill(amber.withA(0.14)))
        .overlay(Capsule().strokeBorder(amber.withA(0.45), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        .fixedSize()
    }
}

#Preview {
    ZStack {
        Theme.screenBG
        VStack(spacing: 16) {
            Chip(accent: AccentOption.blue.color, active: true, mono: true) {
                Icon("distance", size: 14, weight: 2, color: .white)
                Text("DISTANCE")
            }
            Chip(accent: AccentOption.blue.color, mono: true) {
                StatusDot(color: Theme.successGreen, blink: true)
                Text("LiDAR · ACTIVE")
            }
            FallbackBanner()
        }
    }
    .frame(width: 402, height: 300)
}
