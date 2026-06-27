// RoomScanView.swift — guided room capture (RoomPlan on device, scripted in-sim).
//
// Layout (over the capture feed):
//   • top status: "ROOM SCAN" chip + a "CAPTURING" chip (amber "· VISUAL" in fallback)
//   • center guidance copy
//   • mini live floor-plan card building up in the top-right (real partial plan)
//   • bottom progress deck: live coverage ring + wall/area readout + Finish CTA,
//     plus the free-export quota disclosure BEFORE any work is captured
//     (competitive guardrail: never capture first and ransom later).
//
// Device renders RoomPlan's coached RoomCaptureView; the Simulator runs the
// deterministic scripted scan that ends in FloorPlanModel.sample.

import SwiftUI

public struct RoomScanView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    @State private var service = RoomScanService()

    /// Delivered when processing completes: the parametric plan plus the USDZ
    /// filename (nil when 3D export was unavailable).
    private let onComplete: (FloorPlanModel, String?) -> Void
    /// User dismissed without finishing.
    private let onCancel: () -> Void

    public init(onComplete: @escaping (FloorPlanModel, String?) -> Void = { _, _ in },
                onCancel: @escaping () -> Void = {}) {
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The camera/capture backdrop bleeds full-screen; the status chips +
            // progress deck respect the safe area (same fix as ExportView).
            .background(backdrop)
            .onAppear {
                service.start()
                appState.analytics.log(
                    AnalyticsEventName.screenView,
                    [AnalyticsParam.screenName: .string(ScreenName.roomScan)])
            }
        // Surface "Scan failed" even though this screen is presented as a cover.
        .appAlert(appState)
        .onDisappear { if service.phase == .scanning { service.cancel() } }
        .onChange(of: service.phase) { _, phase in
            switch phase {
            case .done:
                if let plan = service.finishedPlan {
                    onComplete(plan, service.usdzFilename)
                }
            case .failed(let message):
                appState.presentAlert(title: "Scan failed", message: message)
                onCancel()
            default:
                break
            }
        }
    }

    // MARK: - Capture feed

    @ViewBuilder
    private var backdrop: some View {
        #if targetEnvironment(simulator)
        // Stylized stand-in + the design's captured-wall ribbons.
        CameraBackdrop(accent: theme.accent,
                       scan: true,
                       mesh: theme.lidar,
                       gridAlpha: theme.lidar ? 0.22 : 0.12)
        FeaturePoints(accent: theme.accent)
        CapturedWalls(accent: theme.accent)
            .ignoresSafeArea()
        #else
        RoomCaptureViewContainer(service: service)
            .ignoresSafeArea()
        #endif
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
                if service.phase == .processing {
                    Chip(accent: theme.accent, mono: true) {
                        StatusDot(color: Theme.successGreen, blink: true)
                        Text("PROCESSING")
                    }
                } else {
                    Chip(accent: theme.accent, mono: true) {
                        StatusDot(color: Theme.successGreen, blink: true)
                        Text("CAPTURING")
                    }
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
            Text("Keep the floor edge in view")
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
            FloorPlan(model: service.livePlan
                        ?? FloorPlanModel(walls: [], openings: [], rooms: [],
                                          widthMeters: 0, heightMeters: 0,
                                          capturedAt: Date(timeIntervalSince1970: 0)),
                      accent: theme.accent, unit: theme.unit,
                      showDims: false, small: true)
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
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                CoverageRing(percent: service.coveragePercent, accent: theme.accent)
                    .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Scanning coverage")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(statusLine)
                        .font(Theme.mono(11.5))
                        .foregroundStyle(Theme.ink2)
                }

                Spacer(minLength: 8)

                finishButton
            }

            // Quota disclosure BEFORE capture (never ransom captured work).
            if !appState.isPro {
                Text("\(max(0, appState.freeExportsLeft)) of 3 free exports left · scans are always saved and viewable")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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

    private var statusLine: String {
        let walls = service.wallCount
        let area = service.estimatedAreaSqM
        guard walls > 0 || area > 0 else { return "Looking for walls…" }
        var parts: [String] = []
        if walls > 0 { parts.append("\(walls) wall\(walls == 1 ? "" : "s")") }
        if area > 0 { parts.append("floor"); parts.append(UnitFormat.area(area, theme.unit)) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var finishButton: some View {
        if service.phase == .processing {
            ProgressView()
                .tint(theme.accent)
                .frame(width: 90, height: 44)
        } else {
            Button {
                // Value-moment: finishing a scan is a core feature win that seeds
                // conversion, so stamp the attribution feature before logging.
                appState.recordValueFeature("room_scan_finished")
                appState.analytics.log(
                    AnalyticsEventName.roomScanFinished,
                    [AnalyticsParam.wallCount: .int(service.wallCount)])
                service.finishScan()
            } label: {
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
            // Require at least one captured wall before finishing — the coverage
            // heuristic alone can read >0 from a floor-only scan, which would save
            // and export a blank plan (and spend a free export on nothing).
            .disabled(service.wallCount == 0)
            .accessibilityLabel("Finish scan")
        }
    }
}

#if !targetEnvironment(simulator)
import RoomPlan

/// Embeds RoomPlan's coached capture view (owned by the service).
private struct RoomCaptureViewContainer: UIViewRepresentable {
    let service: RoomScanService

    func makeUIView(context: Context) -> RoomCaptureView { service.captureView }
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}
#endif

#if targetEnvironment(simulator)
// MARK: - Captured-wall ribbons (simulator decoration only)

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
#endif

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
