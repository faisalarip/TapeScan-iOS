// MeasureAView.swift — the shipped Measure HUD ("Precision").
//
// Dense, instrument-like, mono-everywhere live AR capture:
//   • top HUD: active-mode chip + LiDAR/fallback status chip
//   • technical telemetry strip (TRACK bars · ±precision · DEPTH/EST)
//   • live multi-point geometry from the AR service (segment ValuePills,
//     area fill, angle arc) — every readout computed by MeasureMath
//   • big mono live readout (label + value + total/points)
//   • bottom deck: ModeSwitch + undo / shutter / check
//
// Reliability contract (competitive benchmark): the in-progress session is
// autosaved after every change (SessionDraftStore) and offered for resume on
// return; finishing persists a MeasurementRecord into SwiftData/History.

import SwiftUI
import SwiftData

public struct MeasureAView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    /// AR backend seam (simulated in-sim, ARKit on device from M4).
    private let service: any ARMeasureService
    /// A crash-recovered draft awaiting the user's resume/discard choice.
    @State private var pendingDraft: MeasureSessionDraft?
    @State private var showResumePrompt = false

    public init(service: any ARMeasureService) {
        self.service = service
    }

    @MainActor
    public init() {
        self.service = MeasureServiceFactory.make()
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Camera + AR — mesh/grid density follow LiDAR availability.
            CameraBackdrop(accent: theme.accent,
                           mesh: theme.lidar,
                           gridAlpha: theme.lidar ? 0.22 : 0.12)
            FeaturePoints(accent: theme.accent)

            scene
            ReticleLayer(accent: theme.accent, label: theme.reticleGuidance)

            topHUD
            bigReadout
            bottomDeck
        }
        .background(Theme.cameraBG.ignoresSafeArea())
        .onAppear {
            service.snapEnabled = appState.snapEnabled
            service.start()
            offerResumeIfNeeded()
        }
        .onDisappear { service.stop() }
        .onChange(of: appState.snapEnabled) { _, snap in service.snapEnabled = snap }
        .alert("Resume previous session?", isPresented: $showResumePrompt) {
            Button("Resume") {
                if let draft = pendingDraft {
                    service.load(points: draft.points, mode: draft.mode)
                }
                pendingDraft = nil
            }
            Button("Discard", role: .destructive) {
                SessionDraftStore.clear()
                pendingDraft = nil
            }
        } message: {
            Text("An unfinished measurement was recovered.")
        }
    }

    // MARK: - AR geometry (live)

    private var scene: some View {
        let live = LiveSceneBuilder.build(service: service, unit: theme.unit)
        return MeasureScene(
            accent: theme.accent,
            pts: live.pts,
            segs: live.segs,
            area: live.area,
            angle: live.angle,
            activeTo: ScenePoint(x: 201, y: 470))
        .ignoresSafeArea()
    }

    // MARK: - Top HUD (chips + telemetry strip)

    private var topHUD: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Chip(accent: theme.accent, active: true, mono: true) {
                    Icon(service.mode.icon, size: 14, weight: 2, color: .white)
                    Text(service.mode.chipLabel)
                }
                Spacer()
                LidarStatusChip()
            }

            if !theme.lidar { FallbackBanner() }

            telemetryStrip
        }
        .padding(.horizontal, 14)
        .padding(.top, 44) // clears the floating HUD-style picker in MeasureView
    }

    private var telemetryStrip: some View {
        HStack(spacing: 14) {
            // TRACK quality bars — lit count follows live tracking strength;
            // accent (LiDAR) / amber (fallback).
            HStack(spacing: 5) {
                Text("TRACK").foregroundStyle(Theme.ink3)
                HStack(spacing: 2) {
                    ForEach(Array(trackBars.enumerated()), id: \.offset) { _, opacity in
                        RoundedRectangle(cornerRadius: 1)
                            .fill((theme.lidar ? theme.accent : Theme.amber).opacity(opacity))
                            .frame(width: 3, height: 9)
                    }
                }
            }
            // ± precision
            HStack(spacing: 4) {
                Text("±").foregroundStyle(Theme.ink3)
                Text(theme.precision)
            }
            // DEPTH (LiDAR) / EST (fallback) — live reticle depth.
            HStack(spacing: 4) {
                Text(theme.lidar ? "DEPTH" : "EST").foregroundStyle(Theme.ink3)
                Text(depthText)
            }
            Spacer(minLength: 0)
        }
        .font(Theme.mono(10.5))
        .tracking(0.3)
        .foregroundStyle(Theme.ink2)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: theme.r(10), style: .continuous)
                .fill(Theme.glass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.r(10), style: .continuous)
                .strokeBorder(Theme.glassBorder, lineWidth: 1)
        )
    }

    private var depthText: String {
        guard let depth = service.targetDepthMeters else { return "—" }
        return String(format: "%.2f m", depth)
    }

    /// TRACK bar opacities — lit count follows the live tracking strength.
    private var trackBars: [Double] {
        let lit = Int((service.tracking.strength * 4).rounded())
        return (0..<4).map { $0 < lit ? 1 : 0.3 }
    }

    // MARK: - Big live readout

    private var bigReadout: some View {
        let result = service.result
        return VStack(alignment: .leading, spacing: 0) {
            Text(service.mode.readoutLabel)
                .font(Theme.mono(11))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            Text(readoutValue(result))
                .font(Theme.mono(46, weight: .bold))
                .tracking(-1)
                .foregroundStyle(Theme.ink)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                .padding(.top, 2)
            Text("TOTAL \(UnitFormat.lengthFractional(result.totalLength, unit: theme.unit)) · \(service.points.count) PTS")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.ink2)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 16)
        .padding(.bottom, 188)
    }

    /// Big-readout value for the active mode, live from MeasureMath.
    private func readoutValue(_ result: MeasureResult) -> String {
        switch service.mode {
        case .distance:
            return UnitFormat.lengthFractional(result.segmentLengths.last ?? 0, unit: theme.unit)
        case .area:
            return UnitFormat.area(result.area ?? 0, theme.unit)
        case .volume:
            return UnitFormat.volume(result.volume ?? 0, theme.unit)
        case .angle:
            return UnitFormat.angle(result.angleDegrees ?? 0)
        }
    }

    // MARK: - Bottom control deck

    private var bottomDeck: some View {
        VStack(spacing: 12) {
            ModeSwitch(accent: theme.accent, active: modeBinding)
            HStack {
                MeasureCircleBtn(icon: "undo") {
                    service.undo()
                    autosaveDraft()
                }
                .accessibilityLabel("Undo last point")
                Spacer()
                Shutter(accent: theme.accent, icon: "plus") {
                    if service.placePoint() == nil {
                        appState.presentAlert(
                            title: "No surface found",
                            message: "Aim the reticle at a flat surface and try again.")
                    }
                    autosaveDraft()
                }
                .accessibilityLabel("Add measurement point")
                Spacer()
                MeasureCircleBtn(icon: "check") { finishTapped() }
                    .accessibilityLabel("Finish measurement")
            }
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 40)
    }

    private var modeBinding: Binding<MeasureMode> {
        Binding(get: { service.mode },
                set: { service.mode = $0; autosaveDraft() })
    }

    // MARK: - Persistence (autosave + finish)

    /// Crash-recovery: persist the in-progress session after every change.
    private func autosaveDraft() {
        if service.points.isEmpty {
            SessionDraftStore.clear()
        } else {
            SessionDraftStore.save(MeasureSessionDraft(
                mode: service.mode, points: service.points, savedAt: Date()))
        }
    }

    /// Offer to resume a recent (< 24 h) crash-recovered draft once.
    private func offerResumeIfNeeded() {
        guard service.points.isEmpty || pendingDraft == nil else { return }
        guard let draft = SessionDraftStore.load(),
              !draft.points.isEmpty,
              draft.savedAt > Date(timeIntervalSinceNow: -24 * 3600) else { return }
        pendingDraft = draft
        showResumePrompt = true
    }

    /// Finalize: persist a MeasurementRecord into History, clear the draft.
    private func finishTapped() {
        let points = service.points
        guard let result = service.finish() else { return }
        SessionDraftStore.clear()
        do {
            let count = (try? modelContext.fetchCount(FetchDescriptor<MeasurementRecord>())) ?? 0
            let record = try MeasurementRecord(name: "Measurement \(count + 1)",
                                               mode: result.mode,
                                               points: points,
                                               result: result)
            modelContext.insert(record)
            try modelContext.save()
        } catch {
            appState.presentAlert(
                title: "Couldn't save measurement",
                message: error.localizedDescription)
        }
    }
}

#Preview {
    MeasureAView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
        .modelContainer(ModelContainerFactory.makeInMemory())
}
