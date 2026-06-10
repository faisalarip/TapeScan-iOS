// Icon.swift — the design's named icon set.
//
// Each design icon name maps to the closest SF Symbol where one reads correctly;
// the few that have no good symbol (the L-shape area glyph, the custom volume
// cube, the lidar burst, the ruler) fall back to a hand-drawn `Path` that
// reproduces the source SVG `d=` data on the 24×24 viewBox.
//
// Usage:  Icon("distance", size: 18, weight: 1.8, color: theme.accent)
//   • `weight` is the stroke width in the original 24-pt space (sw=… in source);
//     it is mapped to an SF Symbol weight for symbol-backed glyphs.

import SwiftUI

public struct Icon: View {
    public let name: String
    public let size: CGFloat
    public let strokeWidth: CGFloat
    public let color: Color

    /// - Parameters:
    ///   - name: design icon name (e.g. `"distance"`, `"lidar"`, `"check"`).
    ///   - size: rendered point size (square).
    ///   - weight: stroke width in 24-pt space (source `sw`). Default 1.7.
    ///   - color: stroke / fill color. Default `Theme.ink`.
    public init(_ name: String,
                size: CGFloat = 20,
                weight: CGFloat = 1.7,
                color: Color = Theme.ink) {
        self.name = name
        self.size = size
        self.strokeWidth = weight
        self.color = color
    }

    public var body: some View {
        if let symbol = Self.symbolMap[name] {
            Image(systemName: symbol)
                .font(.system(size: size * 0.92, weight: symbolWeight))
                .foregroundStyle(color)
                .frame(width: size, height: size)
        } else if let path = Self.customPaths[name] {
            path.path
                .stroke(color,
                        style: StrokeStyle(lineWidth: strokeWidth,
                                           lineCap: .round,
                                           lineJoin: .round))
                .frame(width: size, height: size)
        } else {
            // Unknown name → empty box keeps layout stable.
            Color.clear.frame(width: size, height: size)
        }
    }

    private var symbolWeight: Font.Weight {
        switch strokeWidth {
        case ..<1.6: return .regular
        case ..<2.0: return .medium
        case ..<2.4: return .semibold
        default:     return .bold
        }
    }

    // MARK: - SF Symbol mapping (preferred)
    static let symbolMap: [String: String] = [
        "distance": "ruler",
        "undo":     "arrow.uturn.backward",
        "check":    "checkmark",
        "plus":     "plus",
        "layers":   "square.3.layers.3d",
        "gear":     "gearshape",
        "search":   "magnifyingglass",
        "chevron":  "chevron.right",
        "room":     "house",
        "download": "arrow.down.to.line",
        "share":    "square.and.arrow.up",
        "close":    "xmark",
        "cube3d":   "cube",
        "trash":    "trash",
        "scan":     "viewfinder",
        "pin":      "mappin",
        // NOTE: "grid" and "angle" are NOT valid SF Symbol names — they render
        // a blank glyph. Both fall through to `customPaths` below, which reproduce
        // the exact source SVG `d=` data (ui.jsx ICON_PATHS) on the 24×24 viewBox.
    ]

    // MARK: - Custom geometry (no good SF Symbol — ported from source SVG paths)
    static let customPaths: [String: IconPath] = [
        // area: M4 4h16v16H4zM4 9h16M9 4v16
        "area": IconPath { p, s in
            let u = { (v: CGFloat) in v / 24 * s }
            p.addRect(CGRect(x: u(4), y: u(4), width: u(16), height: u(16)))
            p.move(to: CGPoint(x: u(4), y: u(9))); p.addLine(to: CGPoint(x: u(20), y: u(9)))
            p.move(to: CGPoint(x: u(9), y: u(4))); p.addLine(to: CGPoint(x: u(9), y: u(20)))
        },
        // volume / cube3d alt: M12 2l9 5v10l-9 5-9-5V7l9-5zM3 7l9 5 9-5M12 12v10
        "volume": IconPath { p, s in
            let u = { (v: CGFloat) in v / 24 * s }
            p.move(to: CGPoint(x: u(12), y: u(2)))
            p.addLine(to: CGPoint(x: u(21), y: u(7)))
            p.addLine(to: CGPoint(x: u(21), y: u(17)))
            p.addLine(to: CGPoint(x: u(12), y: u(22)))
            p.addLine(to: CGPoint(x: u(3), y: u(17)))
            p.addLine(to: CGPoint(x: u(3), y: u(7)))
            p.closeSubpath()
            p.move(to: CGPoint(x: u(3), y: u(7)))
            p.addLine(to: CGPoint(x: u(12), y: u(12)))
            p.addLine(to: CGPoint(x: u(21), y: u(7)))
            p.move(to: CGPoint(x: u(12), y: u(12))); p.addLine(to: CGPoint(x: u(12), y: u(22)))
        },
        // ruler2: M3 8h18v8H3zM7 8v3M11 8v4M15 8v3M19 8v4
        "ruler2": IconPath { p, s in
            let u = { (v: CGFloat) in v / 24 * s }
            p.addRect(CGRect(x: u(3), y: u(8), width: u(18), height: u(8)))
            p.move(to: CGPoint(x: u(7), y: u(8)));  p.addLine(to: CGPoint(x: u(7), y: u(11)))
            p.move(to: CGPoint(x: u(11), y: u(8))); p.addLine(to: CGPoint(x: u(11), y: u(12)))
            p.move(to: CGPoint(x: u(15), y: u(8))); p.addLine(to: CGPoint(x: u(15), y: u(11)))
            p.move(to: CGPoint(x: u(19), y: u(8))); p.addLine(to: CGPoint(x: u(19), y: u(12)))
        },
        // grid: M3 9h18M3 15h18M9 3v18M15 3v18 (source ui.jsx grid)
        "grid": IconPath { p, s in
            let u = { (v: CGFloat) in v / 24 * s }
            p.move(to: CGPoint(x: u(3), y: u(9)));  p.addLine(to: CGPoint(x: u(21), y: u(9)))
            p.move(to: CGPoint(x: u(3), y: u(15))); p.addLine(to: CGPoint(x: u(21), y: u(15)))
            p.move(to: CGPoint(x: u(9), y: u(3)));  p.addLine(to: CGPoint(x: u(9), y: u(21)))
            p.move(to: CGPoint(x: u(15), y: u(3))); p.addLine(to: CGPoint(x: u(15), y: u(21)))
        },
        // angle: M4 20h16M4 20V6M4 20l13-9 (source ui.jsx angle)
        "angle": IconPath { p, s in
            let u = { (v: CGFloat) in v / 24 * s }
            p.move(to: CGPoint(x: u(4), y: u(20))); p.addLine(to: CGPoint(x: u(20), y: u(20)))
            p.move(to: CGPoint(x: u(4), y: u(20))); p.addLine(to: CGPoint(x: u(4), y: u(6)))
            p.move(to: CGPoint(x: u(4), y: u(20))); p.addLine(to: CGPoint(x: u(17), y: u(11)))
        },
        // lidar: center ring + radiating ticks
        "lidar": IconPath { p, s in
            let u = { (v: CGFloat) in v / 24 * s }
            p.addEllipse(in: CGRect(x: u(10), y: u(10), width: u(4), height: u(4)))
            let ticks: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (12, 4, 12, 6), (12, 18, 12, 20), (4, 12, 6, 12), (18, 12, 20, 12),
                (6.3, 6.3, 7.7, 7.7), (16.3, 16.3, 17.7, 17.7),
                (17.7, 6.3, 16.3, 7.7), (7.7, 16.3, 6.3, 17.7),
            ]
            for (x1, y1, x2, y2) in ticks {
                p.move(to: CGPoint(x: u(x1), y: u(y1)))
                p.addLine(to: CGPoint(x: u(x2), y: u(y2)))
            }
        },
    ]
}

/// A reusable scalable path: builds a `Path` for a square edge length.
public struct IconPath {
    private let build: @Sendable (inout Path, CGFloat) -> Void
    init(_ build: @escaping @Sendable (inout Path, CGFloat) -> Void) { self.build = build }
    var path: some Shape { IconShape(build: build) }
}

private struct IconShape: Shape {
    let build: @Sendable (inout Path, CGFloat) -> Void
    func path(in rect: CGRect) -> Path {
        var p = Path()
        build(&p, min(rect.width, rect.height))
        return p
    }
}
