// TapeMeasureARProApp.swift — SwiftUI App entry point.

import SwiftUI

@main
struct TapeMeasureARProApp: App {
    /// Root-owned application state, injected into the environment.
    @State private var appState = AppState.bootstrapped()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
    }
}
