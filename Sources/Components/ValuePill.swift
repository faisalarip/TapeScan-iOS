// ValuePill.swift — small measurement value label pinned over the AR scene.

import SwiftUI

/// A compact value pill (mono by default) used to annotate measurement
/// segments / areas in the AR scene. `active` fills with accent.
public struct ValuePill: View {
    private let accent: Color
    private let text: String
    private let sub: String?
    private let active: Bool
    private let mono: Bool

    /// - Parameters:
    ///   - text: primary value text (e.g. "2.34 m").
    ///   - sub: optional faint suffix (e.g. unit subscript).
    ///   - accent: fill / border tint. Defaults to live theme accent.
    ///   - active: solid accent fill vs dark glass + accent border. Default false.
    ///   - mono: use mono font. Default true.
    public init(text: String,
                sub: String? = nil,
                accent: Color? = nil,
                active: Bool = false,
                mono: Bool = true) {
        self.text = text
        self.sub = sub
        self.accent = accent ?? Theme.fallback.accent
        self.active = active
        self.mono = mono
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(text)
            if let sub {
                Text(sub)
                    .font(mono ? Theme.mono(9.5, weight: .medium) : Theme.sans(9.5, weight: .medium))
                    .opacity(0.7)
            }
        }
        .font(mono ? Theme.mono(13, weight: .bold) : Theme.sans(13, weight: .bold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(active ? accent.withA(0.92)
                             : Color(.sRGB, red: 10/255, green: 12/255, blue: 15/255, opacity: 0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(active ? .clear : accent.withA(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 7, y: 4)
        .fixedSize()
    }
}

#Preview {
    ZStack {
        Theme.cameraBG
        VStack(spacing: 16) {
            ValuePill(text: "2.34 m", accent: AccentOption.blue.color, active: true)
            ValuePill(text: "1.62 m", accent: AccentOption.blue.color)
        }
    }
    .frame(width: 402, height: 200)
}
