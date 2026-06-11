// SessionDraftStore.swift — crash-recoverable measure-session autosave (M2).
//
// Competitive requirement: never lose in-progress work to a crash (the #1
// negative-review theme across every competitor). The Measure flow saves the
// draft after every point change — a single small JSON file, synchronous on
// purpose: writes are tiny and must land before a potential crash.

import Foundation

public struct MeasureSessionDraft: Codable, Equatable {
    public var mode: MeasureMode
    public var points: [WorldPoint]
    public var savedAt: Date

    public init(mode: MeasureMode, points: [WorldPoint], savedAt: Date) {
        self.mode = mode
        self.points = points
        self.savedAt = savedAt
    }
}

public enum SessionDraftStore {

    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("measure-session-draft.json")
    }

    public static func save(_ draft: MeasureSessionDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    public static func load() -> MeasureSessionDraft? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(MeasureSessionDraft.self, from: data)
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
