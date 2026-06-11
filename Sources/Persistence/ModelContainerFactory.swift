// ModelContainerFactory.swift — SwiftData container setup (M2).

import Foundation
import SwiftData

public enum ModelContainerFactory {

    private static var schema: Schema {
        Schema([MeasurementRecord.self, RoomRecord.self])
    }

    /// The app's on-disk store. A failure here means the app cannot persist
    /// anything (corrupt store / no disk); crashing early with a clear message
    /// beats silently running stateless.
    public static func make() -> ModelContainer {
        do {
            return try ModelContainer(for: schema,
                                      configurations: ModelConfiguration(schema: schema))
        } catch {
            fatalError("TapeScan could not open its data store: \(error)")
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
