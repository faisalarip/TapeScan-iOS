// RoomsView.swift — the Rooms tab host.
//
// Coordinates the room-capture flow that lives behind the "Rooms" tab:
//
//   RoomScan ──"Finish"──▶ Export ──quota hits 0 / "Go Pro"──▶ Paywall
//
// `RoomScanView` runs full-bleed over the camera backdrop. Tapping "Finish"
// presents `ExportView` as a full-screen cover; `ExportView` owns the quota →
// `PaywallView` transition internally (tapping the amber quota meter, or
// spending the final free export, presents the paywall). Closing Export returns
// to the live scan, so the flow is fully re-enterable.

import SwiftUI

/// Hosts the Rooms tab's capture → export flow.
public struct RoomsView: View {
    @Environment(AppState.self) private var appState

    @State private var showExport = false

    public init() {}

    public var body: some View {
        RoomScanView {
            // Finish scan → open the export sheet.
            showExport = true
        }
        .fullScreenCover(isPresented: $showExport) {
            ExportView {
                showExport = false
            }
            .environment(appState)
            .installTheme(Theme(appState))
        }
    }
}

#Preview {
    RoomsView()
        .environment(AppState())
        .installTheme(Theme(accent: AccentOption.blue.color))
}
