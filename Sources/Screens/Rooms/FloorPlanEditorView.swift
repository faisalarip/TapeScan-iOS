// FloorPlanEditorView.swift — post-scan plan editing (M10).
//
// A thin gesture layer over FloorPlanEditorModel: drag welded corners, tap a
// wall to select it (exact-length entry + opening management), undo/redo,
// save back into the RoomRecord (bumping updatedAt so sync picks it up).

import SwiftUI
import SwiftData

public struct FloorPlanEditorView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let room: RoomRecord
    @State private var editor: FloorPlanEditorModel
    @State private var selectedWallID: UUID?
    @State private var lengthInput = ""
    @State private var dragActive = false
    @State private var showDiscardConfirm = false

    public init(room: RoomRecord) {
        self.room = room
        let plan = (try? room.decodedPlan())
            ?? FloorPlanModel(walls: [], openings: [], rooms: [],
                              widthMeters: 0, heightMeters: 0,
                              capturedAt: Date(timeIntervalSince1970: 0))
        _editor = State(initialValue: FloorPlanEditorModel(plan: plan))
    }

    public var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                canvas
                    .padding(14)
                if selectedWallID != nil {
                    wallPanel
                        .padding(.horizontal, 14)
                        .padding(.bottom, 20)
                }
            }
        }
        .confirmationDialog("Discard changes?",
                            isPresented: $showDiscardConfirm,
                            titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button {
                if editor.hasChanges { showDiscardConfirm = true } else { dismiss() }
            } label: {
                Text("Cancel")
                    .font(Theme.sans(14, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                    .frame(minWidth: 60, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel editing")

            Spacer()

            Text("Edit Plan")
                .font(Theme.sans(16, weight: .bold))
                .foregroundStyle(Theme.ink)

            Spacer()

            Button { editor.undo() } label: {
                Icon("undo", size: 17, weight: 2, color: editor.canUndo ? Theme.ink : Theme.ink3)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!editor.canUndo)
            .accessibilityLabel("Undo")

            Button { editor.redo() } label: {
                Icon("undo", size: 17, weight: 2, color: editor.canRedo ? Theme.ink : Theme.ink3)
                    .scaleEffect(x: -1)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!editor.canRedo)
            .accessibilityLabel("Redo")

            Button { save() } label: {
                Text("Save")
                    .font(Theme.sans(14, weight: .bold))
                    .foregroundStyle(editor.hasChanges ? theme.accent : Theme.ink3)
                    .frame(minWidth: 54, minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(!editor.hasChanges)
            .accessibilityLabel("Save plan")
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    // MARK: - Canvas

    /// Fit mapping mirrored from FloorPlan, plus the inverse for gestures.
    private struct Mapping {
        let scale: CGFloat
        let ox: CGFloat
        let oy: CGFloat

        init(size: CGSize, plan: FloorPlanModel) {
            let margin: CGFloat = 34
            let w = max(plan.widthMeters, 0.5), h = max(plan.heightMeters, 0.5)
            scale = min((size.width - margin * 2) / w, (size.height - margin * 2) / h)
            ox = (size.width - w * scale) / 2
            oy = (size.height - h * scale) / 2
        }

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: ox + x * scale, y: oy + y * scale)
        }
        func planX(_ viewX: CGFloat) -> Double { Double((viewX - ox) / scale) }
        func planY(_ viewY: CGFloat) -> Double { Double((viewY - oy) / scale) }
    }

    private var canvas: some View {
        GeometryReader { geo in
            let m = Mapping(size: geo.size, plan: editor.plan)
            ZStack {
                RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                    .fill(Color(hex: "#101216"))

                // The plan itself (walls/openings/labels, no dim rails).
                FloorPlan(model: editor.plan, accent: theme.accent,
                          unit: theme.unit, showDims: false)
                    .padding(34)
                    .allowsHitTesting(false)

                // Wall tap targets + selection highlight at midpoints.
                ForEach(editor.plan.walls) { wall in
                    let mid = m.point((wall.startX + wall.endX) / 2,
                                      (wall.startY + wall.endY) / 2)
                    let selected = wall.id == selectedWallID
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(selected ? theme.accent : Color.white.opacity(0.35))
                        .frame(width: 14, height: 14)
                        .position(mid)
                        .onTapGesture {
                            selectedWallID = selected ? nil : wall.id
                            syncLengthInput()
                        }
                        .accessibilityLabel("Wall \(UnitFormat.lengthFractional(wall.lengthMeters, unit: theme.unit))")
                }

                // Draggable welded corners.
                ForEach(editor.corners) { corner in
                    Circle()
                        .strokeBorder(theme.accent, lineWidth: 2)
                        .background(Circle().fill(Theme.screenBG.opacity(0.85)))
                        .frame(width: 22, height: 22)
                        .position(m.point(corner.x, corner.y))
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { value in
                                    if !dragActive {
                                        dragActive = true
                                        editor.beginGesture()
                                    }
                                    editor.dragCorner(id: corner.id,
                                                      toX: m.planX(value.location.x),
                                                      y: m.planY(value.location.y))
                                }
                                .onEnded { _ in
                                    dragActive = false
                                    syncLengthInput()
                                }
                        )
                        .accessibilityLabel("Corner handle")
                }
            }
        }
    }

    // MARK: - Selected-wall panel

    @ViewBuilder
    private var wallPanel: some View {
        if let wallID = selectedWallID,
           let wall = editor.plan.walls.first(where: { $0.id == wallID }) {
            VStack(spacing: 12) {
                // Exact length entry.
                HStack(spacing: 10) {
                    Text("LENGTH")
                        .font(Theme.mono(10))
                        .tracking(1)
                        .foregroundStyle(Theme.ink3)
                    TextField("", text: $lengthInput,
                              prompt: Text(lengthPlaceholder).foregroundColor(Theme.ink3))
                        .keyboardType(.decimalPad)
                        .font(Theme.mono(16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 90)
                    Text(theme.unit == .imperial ? "ft" : "m")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.ink3)
                    Button("Set") { applyLength(to: wallID) }
                        .font(Theme.sans(14, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Set wall length")
                    Spacer()
                    Text(UnitFormat.lengthFractional(wall.lengthMeters, unit: theme.unit))
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.ink2)
                }

                // Openings on this wall.
                HStack(spacing: 10) {
                    Button { editor.addOpening(kind: .door, on: wallID) } label: {
                        panelChip("＋ Door")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add door")
                    Button { editor.addOpening(kind: .window, on: wallID) } label: {
                        panelChip("＋ Window")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add window")
                    Spacer()
                }

                ForEach(editor.plan.openings.filter { $0.wallID == wallID }) { opening in
                    openingRow(opening, wall: wall)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: theme.r(16), style: .continuous)
                    .fill(Color.white.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(16), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func panelChip(_ label: String) -> some View {
        Text(label)
            .font(Theme.sans(13, weight: .semibold))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(Capsule().fill(theme.accent.withA(0.15)))
    }

    private func openingRow(_ opening: FloorPlanModel.Opening,
                            wall: FloorPlanModel.Wall) -> some View {
        let maxOffset = max(0.01, wall.lengthMeters - opening.width)
        return HStack(spacing: 10) {
            Text(opening.kind == .door ? "Door" : opening.kind == .window ? "Window" : "Opening")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.ink2)
                .frame(width: 60, alignment: .leading)
            Slider(value: Binding(
                get: { opening.offset },
                set: { editor.moveOpening(id: opening.id, offset: $0) }
            ), in: 0...maxOffset)
            .tint(theme.accent)
            .accessibilityLabel("\(opening.kind == .door ? "Door" : "Window") position")
            Button {
                editor.removeOpening(id: opening.id)
            } label: {
                Icon("close", size: 14, weight: 2.2, color: Theme.ink3)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove opening")
        }
    }

    // MARK: - Actions

    private var lengthPlaceholder: String {
        guard let wallID = selectedWallID,
              let wall = editor.plan.walls.first(where: { $0.id == wallID }) else { return "" }
        let value = theme.unit == .imperial ? wall.lengthMeters * 3.28084 : wall.lengthMeters
        return String(format: "%.2f", value)
    }

    private func syncLengthInput() { lengthInput = "" }

    private func applyLength(to wallID: UUID) {
        let normalized = lengthInput.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return }
        let meters = theme.unit == .imperial ? value / 3.28084 : value
        editor.setLength(of: wallID, to: meters)
        lengthInput = ""
    }

    private func save() {
        do {
            try room.updatePlan(editor.normalizedPlan())
            try modelContext.save()
            dismiss()
        } catch {
            appState.presentAlert(title: "Couldn't save plan",
                                  message: error.localizedDescription)
        }
    }
}

#if DEBUG
#Preview {
    let container = ModelContainerFactory.makeInMemory()
    let room = try! RoomRecord(name: "Room 1", plan: .sample, usdzFilename: nil)
    container.mainContext.insert(room)
    return FloorPlanEditorView(room: room)
        .environment(AppState())
        .installTheme(Theme(accent: AccentOption.blue.color))
        .modelContainer(container)
}
#endif
