// Reticle.swift — center targeting reticle with optional pulse + mono label.
// 64×64 ring, center dot, four crosshair ticks; pulse ring scales 1→1.18.

import SwiftUI

public struct Reticle: View {
    private let accent: Color
    private let label: String?
    private let pulse: Bool

    /// - Parameters:
    ///   - accent: ring / dot tint. Defaults to live theme accent.
    ///   - label: optional mono caption rendered below the reticle.
    ///   - pulse: animate the outer pulse ring. Default true.
    public init(accent: Color? = nil, label: String? = nil, pulse: Bool = true) {
        self.accent = accent ?? Theme.fallback.accent
        self.label = label
        self.pulse = pulse
    }

    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if pulse {
                    Circle()
                        .stroke(accent, lineWidth: 1.5)
                        .frame(width: 64, height: 64)
                        .scaleEffect(animate ? 1.18 : 1.0)
                        .opacity(animate ? 0.15 : 0.55)
                }
                // static ring
                Circle()
                    .stroke(accent.withA(0.85), lineWidth: 1.5)
                    .frame(width: 64, height: 64)
                // center dot
                Circle()
                    .fill(accent)
                    .frame(width: 5, height: 5)
                    .shadow(color: accent, radius: 4)
                // crosshair ticks
                ForEach(Array(Self.ticks.enumerated()), id: \.offset) { _, t in
                    Rectangle()
                        .fill(accent)
                        .frame(width: t.dx != 0 ? 7 : 1.5,
                               height: t.dx != 0 ? 1.5 : 7)
                        .offset(x: t.dx, y: t.dy)
                }
            }
            .frame(width: 64, height: 64)

            if let label {
                Text(label)
                    .font(Theme.mono(10.5))
                    .tracking(0.4)
                    .foregroundStyle(Color.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                    .padding(.top, 24)
                    .fixedSize()
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard pulse, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    private struct Tick { let dx, dy: CGFloat }
    private static let ticks: [Tick] = [
        Tick(dx: 0, dy: -10), Tick(dx: 0, dy: 10),
        Tick(dx: -10, dy: 0), Tick(dx: 10, dy: 0),
    ]
}

#Preview {
    ZStack {
        Theme.cameraBG
        Reticle(accent: AccentOption.blue.color, label: "ALIGN · TAP TO SET POINT")
    }
    .frame(width: 402, height: 874)
}
