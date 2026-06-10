// RoomScanView.swift — guided room capture.
// Ported 1:1 from support.jsx `RoomScan` + the verified HTML reference (LiDAR fallback).
//
// Layout (over the camera backdrop):
//   • top status: "ROOM SCAN" chip + a "CAPTURING" chip (amber "· VISUAL" in fallback)
//     and, in fallback, the visual-inertial FallbackBanner
//   • center guidance copy (fallback swaps the sub-line to side-to-side guidance)
//   • mini live floor-plan card building up in the top-right
//   • bottom progress deck: 68% coverage ring + "Scanning coverage" + Finish CTA
//
// All AR theming reads `theme.lidar`; the backdrop uses the LiDAR recon-mesh +
// brighter grid (0.22) vs the dimmer fallback grid (0.12), matching the HTML.

import SwiftUI

public struct RoomScanView: View {
    @Environment(\.theme) private var theme

    /// Coverage percentage shown on the ring + deck. Matches the source (68%).
    private let coverage: Int
    /// Tapping Finish. The flow routes to Export in the real app.
    private let onFinish: () -> Void

    public init(coverage: Int = 68, onFinish: @escaping () -> Void = {}) {
        self.coverage = coverage
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            // Camera backdrop — LiDAR mesh + bright grid vs dim fallback grid.
            CameraBackdrop(accent: theme.accent,
                           scan: true,
                           mesh: theme.lidar,
                           gridAlpha: theme.lidar ? 0.22 : 0.12)
            FeaturePoints(accent: theme.accent)

            // captured-wall ribbons (solid = locked, dashed = in-progress)
            CapturedWalls(accent: theme.accent)
                .ignoresSafeArea()

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            topStatus
            guidance
                .padding(.top, 34)
            Spacer()
            progressDeck
                .padding(.horizontal, 14)
                .padding(.bottom, 38)
        }
        .overlay(alignment: .topTrailing) {
            miniPlanCard
                .padding(.trailing, 16)
                .padding(.top, 162)
        }
    }

    // MARK: - Top status row

    private var topStatus: some View {
        HStack(alignment: .top) {
            Chip(accent: theme.accent, active: true, mono: true) {
                Icon("scan", size: 14, weight: 2, color: .white)
                Text("ROOM SCAN")
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if theme.lidar {
                    Chip(accent: theme.accent, mono: true) {
                        StatusDot(color: Theme.successGreen, blink: true)
                        Text("CAPTURING")
                    }
                } else {
                    Chip(accent: Theme.amber, active: true, mono: true) {
                        StatusDot(color: .white, blink: true)
                        Text("CAPTURING · VISUAL")
                    }
                    FallbackBanner()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    // MARK: - Center guidance

    private var guidance: some View {
        VStack(spacing: 4) {
            Text("Move slowly along the walls")
                .font(Theme.sans(17, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .shadow(color: .black.opacity(0.7), radius: 8, y: 2)
            Text(theme.lidar
                 ? "Keep the floor edge in view"
                 : "Move side-to-side · visual-inertial tracking")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - Mini live floor-plan card

    private var miniPlanCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PLAN")
                .font(Theme.mono(8.5))
                .tracking(1)
                .foregroundStyle(Theme.ink3)
            FloorPlan(accent: theme.accent, unit: theme.unit, showDims: false, small: true)
        }
        .padding(8)
        .frame(width: 104, height: 96)
        .background(
            RoundedRectangle(cornerRadius: theme.r(14), style: .continuous)
                .fill(Color(.sRGB, red: 10/255, green: 12/255, blue: 15/255, opacity: 0.7)))
        .overlay(
            RoundedRectangle(cornerRadius: theme.r(14), style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
    }

    // MARK: - Bottom progress deck

    private var progressDeck: some View {
        HStack(spacing: 16) {
            CoverageRing(percent: coverage, accent: theme.accent)
                .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 3) {
                Text("Scanning coverage")
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("3 walls · floor · \(UnitFormat.area(18.6, theme.unit))\(theme.lidar ? "" : " · VISUAL")")
                    .font(Theme.mono(11.5))
                    .foregroundStyle(Theme.ink2)
            }

            Spacer(minLength: 8)

            Button(action: onFinish) {
                HStack(spacing: 6) {
                    Icon("check", size: 16, weight: 2.4, color: .white)
                    Text("Finish")
                }
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: theme.r(13), style: .continuous)
                        .fill(theme.accent.withA(0.95)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Finish scan")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.r(24), style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.r(24), style: .continuous)
                        .fill(Color(.sRGB, red: 13/255, green: 14/255, blue: 17/255, opacity: 0.82))))
        .overlay(
            RoundedRectangle(cornerRadius: theme.r(24), style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Captured-wall ribbons

/// The two perspective wall ribbons from the source 402×874 viewBox:
///   solid  : 40,560 250,520 250,640 40,690   (locked, accent @ 0.2 fill)
///   dashed : 250,520 360,548 360,672 250,640 (in-progress, accent @ 0.1 fill)
private struct CapturedWalls: View {
    let accent: Color

    private static let vbW: CGFloat = 402
    private static let vbH: CGFloat = 874

    var body: some View {
        GeometryReader { geo in
            ribbons(geo.size)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func ribbons(_ size: CGSize) -> some View {
        let sx = size.width / Self.vbW
        let sy = size.height / Self.vbH
        ZStack {
            WallPoly(points: [(40, 560), (250, 520), (250, 640), (40, 690)], sx: sx, sy: sy)
                .fill(accent.withA(0.2))
            WallPoly(points: [(40, 560), (250, 520), (250, 640), (40, 690)], sx: sx, sy: sy)
                .stroke(accent, lineWidth: 2)

            WallPoly(points: [(250, 520), (360, 548), (360, 672), (250, 640)], sx: sx, sy: sy)
                .fill(accent.withA(0.1))
            WallPoly(points: [(250, 520), (360, 548), (360, 672), (250, 640)], sx: sx, sy: sy)
                .stroke(accent.withA(0.6),
                        style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
        }
    }
}

/// A closed polygon defined in the 402×874 source space, scaled into the frame.
private struct WallPoly: Shape {
    let points: [(CGFloat, CGFloat)]
    let sx: CGFloat
    let sy: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.0 * sx, y: first.1 * sy))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: pt.0 * sx, y: pt.1 * sy))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Coverage ring

/// The 62×62 progress ring from the source: a faint track + accent arc starting
/// at 12-o'clock (rotated -90°), with the percentage centered in mono.
private struct CoverageRing: View {
    let percent: Int
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, percent))) / 100)
                .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(Theme.mono(15, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityLabel("Coverage \(percent) percent")
    }
}

#Preview {
    RoomScanView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
