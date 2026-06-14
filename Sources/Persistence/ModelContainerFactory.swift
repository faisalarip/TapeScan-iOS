// ModelContainerFactory.swift — SwiftData container setup (M2).

import Foundation
import SwiftData

public enum ModelContainerFactory {

    private static var schema: Schema {
        Schema([MeasurementRecord.self, RoomRecord.self])
    }

    /// The app's on-disk store. If the existing store is corrupt or schema-
    /// incompatible, RECOVER instead of crash-looping the app on every launch:
    /// move the bad store aside and retry a fresh one; if even that fails, run
    /// in-memory for this session so the app still launches (new data won't
    /// persist) rather than being permanently unusable until reinstall.
    public static func make() -> ModelContainer {
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            moveStoreAside(at: config.url)
            if let recovered = try? ModelContainer(for: schema, configurations: config) {
                return recovered
            }
            if let memory = try? ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)) {
                return memory
            }
            fatalError("TapeScan could not create any data store: \(error)")
        }
    }

    /// Renames a corrupt store (and its `-wal`/`-shm` SQLite sidecars) aside so a
    /// fresh store can be created. Best-effort; failures are ignored.
    private static func moveStoreAside(at storeURL: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: storeURL.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = URL(fileURLWithPath: storeURL.path + suffix + ".corrupt")
            try? fm.removeItem(at: dst)
            try? fm.moveItem(at: src, to: dst)
        }
    }

    /// In-memory container for tests and previews.
    public static func makeInMemory() -> ModelContainer {
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("in-memory store creation failed: \(error)")
        }
    }
}
