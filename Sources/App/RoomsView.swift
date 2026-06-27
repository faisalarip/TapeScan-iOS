// RoomsView.swift — the Rooms tab: saved rooms library + scan entry.
//
// Flow:  [New Scan] ──▶ RoomScanView ──processing done──▶ RoomRecord saved
//        ──▶ ExportView(room:) · saved rooms reopen ExportView anytime
//        (created content stays viewable forever, regardless of entitlement).
//
// Non-LiDAR devices can't run RoomPlan: the scan entry is replaced by an
// explainer, while synced/saved rooms remain fully viewable.

import SwiftUI
import SwiftData

/// Hosts the Rooms tab: saved-room library, the scan flow, and export.
public struct RoomsView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(RoomRecord.visibleDescriptor()) private var rooms: [RoomRecord]

    @State private var showScan = false
    @State private var exportRoom: RoomRecord?
    @State private var pendingDeleteRoom: RoomRecord?
    @State private var renameRoomRecord: RoomRecord?
    @State private var renameText = ""

    public init() {}

    public var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                title
                ScrollView {
                    VStack(spacing: 18) {
                        scanEntry
                        roomsList
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
        }
        .fullScreenCover(isPresented: $showScan) {
            RoomScanView(onComplete: { plan, usdzFilename in
                showScan = false
                saveRoom(plan: plan, usdzFilename: usdzFilename)
            }, onCancel: {
                showScan = false
            })
            .environment(appState)
            .installTheme(Theme(appState))
        }
        .fullScreenCover(item: $exportRoom) { room in
            ExportView(room: room) {
                exportRoom = nil
            }
            .environment(appState)
            .installTheme(Theme(appState))
        }
        // Confirm before deleting — it tombstones + syncs (removes from the cloud too).
        .confirmationDialog("Delete this room?",
                            isPresented: Binding(get: { pendingDeleteRoom != nil },
                                                 set: { if !$0 { pendingDeleteRoom = nil } }),
                            titleVisibility: .visible,
                            presenting: pendingDeleteRoom) { room in
            Button("Delete", role: .destructive) {
                delete(room)
                pendingDeleteRoom = nil
            }
        }
        .alert("Rename room",
               isPresented: Binding(get: { renameRoomRecord != nil },
                                    set: { if !$0 { renameRoomRecord = nil } })) {
            TextField("Name", text: $renameText)
            Button("Save") { commitRename() }
            Button("Cancel", role: .cancel) { renameRoomRecord = nil }
        }
    }

    // MARK: - Title

    private var title: some View {
        HStack {
            Text("Rooms")
                .font(Theme.sans(30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Scan entry

    @ViewBuilder
    private var scanEntry: some View {
        if RoomScanService.isSupported {
            Button {
                // Funnel: user opened the room-scan flow (engagement signal).
                appState.analytics.log(AnalyticsEventName.roomScanStarted)
                showScan = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: theme.r(12), style: .continuous)
                            .fill(Color.white.opacity(0.2))
                        Icon("scan", size: 24, weight: 1.8, color: .white)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("New Room Scan")
                            .font(Theme.sans(16, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("Walk the room → instant floor plan")
                            .font(Theme.sans(12.5))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    Spacer(minLength: 8)
                    Icon("scan", size: 18, weight: 2, color: .white)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                        .fill(LinearGradient(
                            colors: [theme.accent.withA(0.9), theme.accent.withA(0.55)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start a new room scan")
        } else {
            HStack(spacing: 12) {
                Icon("lidar", size: 20, weight: 1.8, color: Theme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Room scan requires LiDAR")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Available on iPhone Pro and iPad Pro models with LiDAR. Tape measuring works on this device — and synced rooms appear below.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.ink2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.r(14), style: .continuous)
                    .fill(Theme.amber.withA(0.1)))
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(14), style: .continuous)
                    .strokeBorder(Theme.amber.withA(0.35), lineWidth: 1))
        }
    }

    // MARK: - Saved rooms

    @ViewBuilder
    private var roomsList: some View {
        if rooms.isEmpty {
            VStack(spacing: 8) {
                Icon("room", size: 30, weight: 1.8, color: Theme.ink3)
                Text("No rooms yet")
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                Text("Scan a room and its floor plan will be saved here.")
                    .font(Theme.sans(13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
        } else {
            DListSection(header: "Saved rooms") {
                ForEach(Array(rooms.enumerated()), id: \.element.id) { index, room in
                    DRow(icon: "room",
                         title: room.name,
                         subtitle: room.createdAt.formatted(date: .abbreviated, time: .omitted),
                         detail: UnitFormat.area(room.areaSquareMeters, theme.unit),
                         last: index == rooms.count - 1,
                         action: { exportRoom = room }, accessory: {
                        Chevron()
                    })
                    .accessibilityLabel("\(room.name), \(UnitFormat.area(room.areaSquareMeters, theme.unit))")
                    .contextMenu {
                        Button {
                            renameText = room.name
                            renameRoomRecord = room
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            pendingDeleteRoom = room
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveRoom(plan: FloorPlanModel, usdzFilename: String?) {
        do {
            let count = (try? modelContext.fetchCount(FetchDescriptor<RoomRecord>())) ?? 0
            let record = try RoomRecord(name: "Room \(count + 1)",
                                        plan: plan,
                                        usdzFilename: usdzFilename)
            modelContext.insert(record)
            try modelContext.save()
            // Value-moment: a completed scan is now persisted as a RoomRecord.
            // Stamp attribution (first/last value-feature) before logging so the
            // paywall funnel can later credit this feature for the conversion.
            appState.recordValueFeature("room_saved")
            appState.analytics.log(AnalyticsEventName.roomSaved)
            exportRoom = record
        } catch {
            appState.presentAlert(title: "Couldn't save room",
                                  message: error.localizedDescription)
        }
    }

    private func delete(_ room: RoomRecord) {
        // Remove the on-disk 3D capture too — the USDZ is device-local (never
        // synced), so a tombstone+sync purge would otherwise leak the file forever.
        if let filename = room.usdzFilename {
            try? FileManager.default.removeItem(
                at: RoomScanService.roomsDirectory.appendingPathComponent(filename))
        }
        room.markDeleted()
        do {
            try modelContext.save()
        } catch {
            appState.presentAlert(title: "Couldn't delete",
                                  message: error.localizedDescription)
        }
    }

    private func commitRename() {
        defer { renameRoomRecord = nil }
        guard let room = renameRoomRecord else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != room.name else { return }
        room.name = trimmed
        room.updatedAt = Date()   // bump so the rename syncs
        do {
            try modelContext.save()
        } catch {
            appState.presentAlert(title: "Couldn't rename",
                                  message: error.localizedDescription)
        }
    }
}

#Preview {
    RoomsView()
        .environment(AppState())
        .installTheme(Theme(accent: AccentOption.blue.color))
        .modelContainer(ModelContainerFactory.makeInMemory())
}
