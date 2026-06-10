// FeaturePoints.swift — deterministic tracked-point cloud overlay.
// Ports the source `FEAT_PTS` LCG so the cloud is identical every render.

import SwiftUI

public struct FeaturePoints: View {
    private let accent: Color

    public init(accent: Color? = nil) { self.accent = accent ?? Theme.fallback.accent }

    private struct Pt { let x, y, o, r: CGFloat }

    private static let points: [Pt] = {
        var seed: UInt64 = 7
        func rnd() -> CGFloat {
            seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
            return CGFloat(seed) / CGFloat(0x7fffffff)
        }
        return (0..<34).map { _ in
            let x = 8 + rnd() * 84          // percent
            let y = 20 + rnd() * 74         // percent
            let o = 0.18 + rnd() * 0.5
            let r: CGFloat = rnd() > 0.85 ? 2 : 1.3
            return Pt(x: x, y: y, o: o, r: r)
        }
    }()

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(0..<Self.points.count, id: \.self) { i in
                    let p = Self.points[i]
                    Circle()
                        .fill(accent.withA(Double(p.o)))
                        .frame(width: p.r * 2, height: p.r * 2)
                        .shadow(color: accent.withA(Double(p.o) * 0.7), radius: p.r * 1.5)
                        .position(x: geo.size.width * p.x / 100,
                                  y: geo.size.height * p.y / 100)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Theme.cameraBG
        FeaturePoints(accent: AccentOption.cyan.color)
    }
    .frame(width: 402, height: 874)
}
