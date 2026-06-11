// TapeMeasureARProApp.swift — SwiftUI App entry point.

import SwiftUI
import SwiftData

@main
struct TapeMeasureARProApp: App {
    /// Root-owned application state, injected into the environment.
    @State private var appState = AppState.bootstrapped()
    /// The on-disk SwiftData store (measurements + rooms).
    private let modelContainer = ModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
                .task {
                    // isPro is DERIVED state: checked from StoreKit entitlements
                    // at launch, then kept current by the transaction listener
                    // (renewals, Ask-to-Buy approvals, refunds). Never stored.
                    appState.isPro = await StoreKitPurchaseService.currentEntitlementIsPro()
                    await StoreKitPurchaseService.listenForTransactionUpdates { isPro in
                        appState.isPro = isPro
                    }
                }
        }
    }
}
