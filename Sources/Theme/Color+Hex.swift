// Color+Hex.swift — hex string → SwiftUI Color, plus opacity helpers.

import SwiftUI

public extension Color {
    /// Creates a color from a `#RRGGBB` or `#RGB` (or alpha-prefixed) hex string.
    /// Mirrors the design's `withA(hex, a)` parsing. Falls back to clear on bad input.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r, g, b, a: Double
        switch s.count {
        case 3: // RGB (12-bit)
            r = Double((int >> 8) & 0xF) / 15.0
            g = Double((int >> 4) & 0xF) / 15.0
            b = Double(int & 0xF) / 15.0
            a = 1.0
        case 6: // RRGGBB (24-bit)
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = 1.0
        case 8: // AARRGGBB (32-bit)
            a = Double((int >> 24) & 0xFF) / 255.0
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

public extension Color {
    /// Returns this color at the given opacity. Equivalent to the design's `withA(...)`.
    func withA(_ alpha: Double) -> Color { opacity(alpha) }
}
