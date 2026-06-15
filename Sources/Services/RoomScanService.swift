// RoomScanService.swift — guided room capture via Apple RoomPlan (M5).
//
// Device: owns a RoomCaptureView (RoomPlan's coached capture UI), republishes
// live metrics (wall count, floor area, coverage heuristic) and a live
// partial FloorPlanModel during the scan, then processes the final
// CapturedRoom: USDZ export to Application Support/Rooms plus conversion to
// the parametric plan through the pure CapturedRoomConverter.
//
// Simulator: a deterministic scripted scan that ends in FloorPlanModel.sample
// so the whole flow is demonstrable without LiDAR hardware.
//
// RoomPlan requires LiDAR — `isSupported` gates the Rooms tab's scan entry.

import Foundation
import Observation
#if !targetEnvironment(simulator)
import RoomPlan
import simd
#endif

@MainActor
@Observable
public final class RoomScanService {

    public enum Phase: Equatable {
        case idle
        case scanning
        case processing
        case done
        case failed(String)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var coveragePercent = 0
    public private(set) var wallCount = 0
    public private(set) var estimatedAreaSqM: Double = 0
    /// Live partial plan for the mini plan card, rebuilt as RoomPlan updates.
    public private(set) var livePlan: FloorPlanModel?
    /// Final outputs, valid when `phase == .done`.
    public private(set) var finishedPlan: FloorPlanModel?
    public private(set) var usdzFilename: String?

    /// Room scan requires LiDAR (RoomPlan); the Simulator runs the scripted scan.
    public static var isSupported: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return RoomCaptureSession.isSupported
        #endif
    }

    /// Directory holding exported room USDZ files.
    public static var roomsDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("Rooms", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    #if !targetEnvironment(simulator)
    /// RoomPlan's coached capture view; RoomScanView embeds it full-bleed.
    /// (@ObservationIgnored: a UIView reference, not UI-driving state — and
    /// the @Observable macro cannot wrap `lazy` storage.)
    @ObservationIgnored public private(set) lazy var captureView: RoomCaptureView = {
        let view = RoomCaptureView(frame: .zero)
        view.delegate = proxy
        view.captureSession.delegate = proxy
        return view
    }()
    @ObservationIgnored private let proxy = RoomScanProxy()

    // Live-update coalescing (see handleLiveUpdate): keep only the LATEST room
    // and convert at most one at a time, off the main actor.
    @ObservationIgnored private var pendingLiveRoom: CapturedRoom?
    @ObservationIgnored private var isConvertingLiveRoom = false
    #endif

    @ObservationIgnored private var simulatedScanTask: Task<Void, Never>?

    public init() {
        #if !targetEnvironment(simulator)
        proxy.service = self
        #endif
    }

    // MARK: - Lifecycle

    public func start() {
        guard phase == .idle || phase == .done else { return }
        resetOutputs()
        phase = .scanning
        #if targetEnvironment(simulator)
        runSimulatedScan()
        #else
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
        #endif
    }

    /// Finish the capture and process the result.
    public func finishScan() {
        guard phase == .scanning else { return }
        phase = .processing
        #if targetEnvironment(simulator)
        simulatedScanTask?.cancel()
        simulatedScanTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self, !Task.isCancelled else { return }
            self.finishedPlan = .sample
            self.usdzFilename = nil
            self.phase = .done
        }
        #else
        pendingLiveRoom = nil   // stop draining live updates; we're processing now
        captureView.captureSession.stop()
        // RoomPlan now processes; RoomScanProxy.didPresent delivers the result.
        #endif
    }

    /// Abandon the scan (user dismissed mid-capture).
    public func cancel() {
        simulatedScanTask?.cancel()
        #if !targetEnvironment(simulator)
        if phase == .scanning {
            captureView.captureSession.stop(pauseARSession: true)
        }
        pendingLiveRoom = nil
        #endif
        phase = .idle
        resetOutputs()
    }

    private func resetOutputs() {
        coveragePercent = 0
        wallCount = 0
        estimatedAreaSqM = 0
        livePlan = nil
        finishedPlan = nil
        usdzFilename = nil
    }

    // MARK: - Simulated scan (Simulator / previews)

    private func runSimulatedScan() {
        simulatedScanTask?.cancel()
        simulatedScanTask = Task { [weak self] in
            // Scripted, deterministic ramp to the design's canonical 68%.
            for step in 1...17 {
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard let self, !Task.isCancelled, self.phase == .scanning else { return }
                self.coveragePercent = min(68, step * 4)
                self.wallCount = min(3, step / 4)
                self.estimatedAreaSqM = min(18.6, Double(step) * 1.2)
                #if DEBUG
                // `.sample` is a DEBUG-only fixture; the simulated scan only runs in
                // the Simulator (see `start()`), so the device Release build that
                // archives for the App Store must not reference it.
                if step == 10 { self.livePlan = .sample }
                #endif
            }
        }
    }

    // MARK: - Device capture events (forwarded by RoomScanProxy)

    #if !targetEnvironment(simulator)
    fileprivate func handleLiveUpdate(_ room: CapturedRoom) {
        // RoomPlan streams `didUpdate` many times per second. Converting the room
        // to a FloorPlanModel and redrawing the live plan on EVERY update floods
        // the main actor (unbounded Task backlog + per-update geometry + Canvas
        // redraw) and freezes the UI mid-scan. Coalesce to the LATEST room and run
        // at most one conversion at a time, OFF the main actor — bursts collapse to
        // "latest wins" and the heavy geometry never blocks the UI.
        guard phase == .scanning else { return }
        pendingLiveRoom = room
        pumpLiveUpdatesIfIdle()
    }

    private func pumpLiveUpdatesIfIdle() {
        guard phase == .scanning, !isConvertingLiveRoom, let room = pendingLiveRoom else { return }
        pendingLiveRoom = nil
        isConvertingLiveRoom = true
        let capturedAt = Date()
        Task.detached(priority: .utility) { [weak self] in
            let snapshot = RoomScanService.liveSnapshot(of: room, capturedAt: capturedAt)
            await MainActor.run {
                guard let self else { return }
                self.isConvertingLiveRoom = false
                if self.phase == .scanning { self.apply(snapshot) }
                // Drain whatever arrived while this conversion was running.
                self.pumpLiveUpdatesIfIdle()
            }
        }
    }

    private func apply(_ snapshot: LiveSnapshot) {
        wallCount = snapshot.wallCount
        estimatedAreaSqM = snapshot.areaSqM
        coveragePercent = snapshot.coverage
        livePlan = snapshot.plan
    }

    /// Immutable result of converting one captured room off the main actor.
    private struct LiveSnapshot {
        let wallCount: Int
        let areaSqM: Double
        let coverage: Int
        let plan: FloorPlanModel
    }

    /// Pure + main-actor-free: derive the live metrics and parametric plan for one
    /// captured room. Runs on a background task so heavy geometry never blocks UI.
    nonisolated private static func liveSnapshot(of room: CapturedRoom,
                                                 capturedAt: Date) -> LiveSnapshot {
        let walls = room.walls.count
        let floorArea = room.floors.reduce(0.0) {
            $0 + Double($1.dimensions.x) * Double($1.dimensions.y)
        }
        // Coverage heuristic: walls dominate, floor detection adds the rest.
        let coverage = min(95, walls * 22 + (room.floors.isEmpty ? 0 : 12))
        let plan = CapturedRoomConverter.convert(extract(room), capturedAt: capturedAt)
        return LiveSnapshot(wallCount: walls, areaSqM: floorArea, coverage: coverage, plan: plan)
    }

    fileprivate func handleProcessedResult(_ room: CapturedRoom) {
        // Export (USDZ disk write) + conversion are heavy; doing them on the main
        // actor froze the UI during "Processing". Run them off-main, then publish
        // the result and advance to .done back on the main actor.
        let dir = Self.roomsDirectory
        let capturedAt = Date()
        Task.detached(priority: .userInitiated) { [weak self] in
            let filename = UUID().uuidString + ".usdz"
            var savedFilename: String? = filename
            do {
                try room.export(to: dir.appendingPathComponent(filename),
                                exportOptions: .parametric)
            } catch {
                savedFilename = nil   // plan still usable without the 3D capture
            }
            let plan = CapturedRoomConverter.convert(RoomScanService.extract(room),
                                                     capturedAt: capturedAt)
            await MainActor.run {
                guard let self else { return }
                self.usdzFilename = savedFilename
                self.finishedPlan = plan
                self.phase = .done
            }
        }
    }

    fileprivate func handleFailure(_ error: Error) {
        phase = .failed(error.localizedDescription)
    }

    /// Thin extraction shim: CapturedRoom → the pure ScannedRoomData.
    /// `nonisolated` so it can run on the background conversion task.
    nonisolated private static func extract(_ room: CapturedRoom) -> ScannedRoomData {
        var surfaces: [ScannedRoomData.Surface] = []
        surfaces += room.walls.map {
            ScannedRoomData.Surface(transform: $0.transform, width: $0.dimensions.x,
                                    height: $0.dimensions.y, category: .wall)
        }
        surfaces += room.doors.map {
            ScannedRoomData.Surface(transform: $0.transform, width: $0.dimensions.x,
                                    height: $0.dimensions.y, category: .door)
        }
        surfaces += room.windows.map {
            ScannedRoomData.Surface(transform: $0.transform, width: $0.dimensions.x,
                                    height: $0.dimensions.y, category: .window)
        }
        surfaces += room.openings.map {
            ScannedRoomData.Surface(transform: $0.transform, width: $0.dimensions.x,
                                    height: $0.dimensions.y, category: .opening)
        }

        // The floor's polygon corners (surface-local) → world XZ.
        var floorPolygon: [SIMD2<Float>]?
        if let floor = room.floors.first, floor.polygonCorners.count >= 3 {
            floorPolygon = floor.polygonCorners.map { corner in
                let world = floor.transform * SIMD4<Float>(corner.x, corner.y, corner.z, 1)
                return SIMD2<Float>(world.x, world.z)
            }
        }
        return ScannedRoomData(surfaces: surfaces, floorPolygonXZ: floorPolygon)
    }
    #endif
}

#if !targetEnvironment(simulator)
// MARK: - Delegate proxy

/// Bridges RoomPlan's delegate callbacks (arbitrary queue) onto the service's
/// main actor. RoomCaptureViewDelegate requires NSCoding — encoded as nothing;
/// the @objc name keeps archiving stable despite `private`.
@objc(TapeScanRoomScanProxy)
private final class RoomScanProxy: NSObject, RoomCaptureSessionDelegate, RoomCaptureViewDelegate {
    weak var service: RoomScanService?

    // Live model stream during the scan.
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        Task { @MainActor [weak service] in service?.handleLiveUpdate(room) }
    }

    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        if let error {
            Task { @MainActor [weak service] in service?.handleFailure(error) }
        }
    }

    // Final processed result after stop().
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        Task { @MainActor [weak service] in
            if let error {
                service?.handleFailure(error)
            } else {
                service?.handleProcessedResult(processedResult)
            }
        }
    }

    // NSCoding (required by RoomCaptureViewDelegate; never archived).
    func encode(with coder: NSCoder) {}
    required init?(coder: NSCoder) { super.init() }
    override init() { super.init() }
}
#endif
