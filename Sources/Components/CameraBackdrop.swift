// CameraBackdrop.swift — pure-SwiftUI camera-feed stand-in.
//
// Reproduces the design's layered CSS look WITHOUT ARKit so it runs in the
// Simulator: dim-interior gradient, soft key + warm fill lights, wall/floor
// seam, an accent perspective floor grid, optional LiDAR recon-mesh, film
// grain, optional scan sweep, and a vignette. The real camera/LiDAR feed is
// injected later behind `ARMeasureService` — this view is the visual fallback.

import SwiftUI

public struct CameraBackdrop: View {
    private let accent: Color
    private let plane: Bool
    private let scan: Bool
    private let warmth: Double
    private let mesh: Bool
    private let gridAlpha: Double

    /// - Parameters:
    ///   - accent: grid / mesh tint. Defaults to the live theme accent.
    ///   - plane: draw the perspective floor grid. Default true.
    ///   - scan: animate a top-down scan sweep. Default false.
    ///   - warmth: warm fill-light boost 0…1. Default 0.
    ///   - mesh: draw the LiDAR recon-mesh wireframe (LiDAR mode only). Default false.
    ///   - gridAlpha: grid line opacity (0.22 LiDAR / 0.12 fallback). Default 0.22.
    public init(accent: Color? = nil,
                plane: Bool = true,
                scan: Bool = false,
                warmth: Double = 0,
                mesh: Bool = false,
                gridAlpha: Double = 0.22) {
        self.accent = accent ?? Theme.fallback.accent
        self.plane = plane
        self.scan = scan
        self.warmth = warmth
        self.mesh = mesh
        self.gridAlpha = gridAlpha
    }

    @State private var scanPhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Theme.cameraBG

                // room lighting — vertical gradient
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#22262d"), location: 0.0),
                        .init(color: Color(hex: "#191c22"), location: 0.38),
                        .init(color: Color(hex: "#101216"), location: 0.64),
                        .init(color: Color(hex: "#0a0b0e"), location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom)

                // cool key light upper-right
                RadialGradient(
                    colors: [Color(.sRGB, red: 150/255, green: 166/255, blue: 190/255, opacity: 0.22), .clear],
                    center: UnitPoint(x: 0.72, y: 0.14),
                    startRadius: 0, endRadius: max(w, h) * 0.7)

                // warm fill lower-left
                RadialGradient(
                    colors: [Color(hex: "#caa37a").withA(0.10 + warmth * 0.08), .clear],
                    center: UnitPoint(x: 0.38, y: 0.92),
                    startRadius: 0, endRadius: max(w, h) * 0.6)

                // wall / floor seam at 58%
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
                    .position(x: w / 2, y: h * 0.58)

                // perspective floor grid
                if plane {
                    PerspectiveGrid(color: accent.withA(gridAlpha))
                        .frame(width: w, height: h * 0.54)
                        .position(x: w / 2, y: h * 0.58 + h * 0.27)
                        .mask(
                            RadialGradient(
                                colors: [.black, .clear],
                                center: .top, startRadius: 0, endRadius: h * 0.45)
                            .frame(width: w, height: h * 0.54)
                            .position(x: w / 2, y: h * 0.58 + h * 0.27)
                        )
                }

                // LiDAR recon-mesh (LiDAR only)
                if mesh {
                    ReconMesh(accent: accent)
                }

                // film grain
                FilmGrain().opacity(0.06)

                // scan sweep
                if scan {
                    LinearGradient(
                        colors: [.clear, accent.withA(0.18)],
                        startPoint: .top, endPoint: .bottom)
                    .frame(height: h * 0.4)
                    .position(x: w / 2, y: h * (scanPhase))
                    .opacity(scanPhase < 0.2 || scanPhase > 1.0 ? 0 : 0.5)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: false)) {
                            scanPhase = 1.3
                        }
                    }
                }

                // vignette
                RadialGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    center: .center, startRadius: min(w, h) * 0.25, endRadius: max(w, h) * 0.75)
            }
            .clipped()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Perspective floor grid

/// Accent grid lines tilted to read as a floor receding to the horizon.
/// Approximates the CSS `rotateX(64deg)` plane with a trapezoidal line field.
private struct PerspectiveGrid: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let horizonInset = w * 0.42        // how far the far edge converges
            let rows = 9
            let cols = 11

            // horizontal lines (closer together toward the top/horizon)
            for i in 0...rows {
                let f = CGFloat(i) / CGFloat(rows)
                let y = h * pow(f, 1.7)        // ease so they bunch near horizon
                let inset = horizonInset * (1 - f)
                var line = Path()
                line.move(to: CGPoint(x: inset, y: y))
                line.addLine(to: CGPoint(x: w - inset, y: y))
                ctx.stroke(line, with: .color(color), lineWidth: 1)
            }
            // converging vertical lines
            for j in 0...cols {
                let f = CGFloat(j) / CGFloat(cols)
                let topX = horizonInset + (w - 2 * horizonInset) * f
                let botX = w * f
                var line = Path()
                line.move(to: CGPoint(x: topX, y: 0))
                line.addLine(to: CGPoint(x: botX, y: h))
                ctx.stroke(line, with: .color(color), lineWidth: 1)
            }
        }
    }
}

// MARK: - LiDAR reconstructed mesh wireframe

/// Faint triangulated wireframe hugging the floor band — LiDAR-mode only.
/// Vertices use the same deterministic LCG jitter as the source `MESH_PTS`.
public struct ReconMesh: View {
    let accent: Color

    public init(accent: Color? = nil) { self.accent = accent ?? Theme.fallback.accent }

    public var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let tris = Self.triangles(w: w, h: h)
                let fill = accent.withA(0.025)
                let stroke = accent.withA(0.16)
                for t in tris {
                    var p = Path()
                    p.move(to: t[0]); p.addLine(to: t[1]); p.addLine(to: t[2]); p.closeSubpath()
                    ctx.fill(p, with: .color(fill))
                    ctx.stroke(p, with: .color(stroke), lineWidth: 0.6)
                }
            }
            .mask(
                RadialGradient(colors: [.black, .clear],
                               center: UnitPoint(x: 0.5, y: 0.86),
                               startRadius: 0, endRadius: max(geo.size.width, geo.size.height) * 0.6)
            )
        }
        .allowsHitTesting(false)
    }

    /// Deterministic floor-band triangle grid (cols 7 × rows 5).
    private static func triangles(w: CGFloat, h: CGFloat) -> [[CGPoint]] {
        var seed: UInt64 = 19
        func rnd() -> CGFloat {
            seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
            return CGFloat(seed) / CGFloat(0x7fffffff)
        }
        let cols = 7, rows = 5
        let top: CGFloat = 0.6, bot: CGFloat = 0.99
        var grid: [[CGPoint]] = []
        for r in 0..<rows {
            var row: [CGPoint] = []
            let fy = top + (bot - top) * (CGFloat(r) / CGFloat(rows - 1))
            let inset = 0.5 - 0.5 * (1 - (CGFloat(r) / CGFloat(rows - 1)) * 0.82)
            for c in 0..<cols {
                let fx = inset + (1 - 2 * inset) * (CGFloat(c) / CGFloat(cols - 1))
                let jx = (rnd() - 0.5) * 10
                let jy = (rnd() - 0.5) * 7
                row.append(CGPoint(x: fx * w + jx, y: fy * h + jy))
            }
            grid.append(row)
        }
        var tris: [[CGPoint]] = []
        for r in 0..<(rows - 1) {
            for c in 0..<(cols - 1) {
                let a = grid[r][c], b = grid[r][c + 1]
                let d = grid[r + 1][c], e = grid[r + 1][c + 1]
                tris.append([a, b, e])
                tris.append([a, e, d])
            }
        }
        return tris
    }
}

// MARK: - Film grain

/// Subtle static noise overlay (overlay-blended at low opacity).
private struct FilmGrain: View {
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 1
            func rnd() -> CGFloat {
                seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
                return CGFloat(seed) / CGFloat(0x7fffffff)
            }
            let step: CGFloat = 3
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let g = rnd()
                    if g > 0.6 {
                        ctx.fill(Path(CGRect(x: x, y: y, width: step, height: step)),
                                 with: .color(.white.opacity(Double(g) * 0.5)))
                    }
                    y += step
                }
                x += step
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

#Preview {
    CameraBackdrop(accent: AccentOption.blue.color, mesh: true)
        .frame(width: 402, height: 874)
}
