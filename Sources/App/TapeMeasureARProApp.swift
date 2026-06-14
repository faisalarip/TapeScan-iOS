// TapeMeasureARProApp.swift — SwiftUI App entry point.

import SwiftUI
import SwiftData

@main
struct TapeMeasureARProApp: App {
    /// Root-owned application state, injected into the environment.
    @State private var appState = AppState.bootstrapped()
    /// The on-disk SwiftData store (measurements + rooms).
    private let modelContainer = ModelContainerFactory.make()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
                .task {
                    // Restore any signed-in session, then sync.
                    await SupabaseAuthService.shared.loadSession()
                    appState.isAuthenticated = SupabaseAuthService.shared.userID != nil
                    await syncIfSignedIn()

                    // isPro is DERIVED state: checked from StoreKit entitlements
                    // at launch, then kept current by the transaction listener
                    // (renewals, Ask-to-Buy approvals, refunds). Never stored.
                    appState.isPro = await StoreKitPurchaseService.currentEntitlementIsPro()
                    await StoreKitPurchaseService.listenForTransactionUpdates { isPro in
                        appState.isPro = isPro
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Foreground sync keeps devices converged without polling.
                    if phase == .active {
                        Task { await syncIfSignedIn() }
                    }
                }
                .onChange(of: appState.isAuthenticated) { _, isAuth in
                    // Sign-in mid-session: push guest data + pull the account's
                    // records now, instead of waiting for the next cold launch.
                    if isAuth { Task { await syncIfSignedIn() } }
                }
        }
    }

    /// One push+pull cycle when an account is signed in. Failures are silent
    /// by design — sync never blocks or nags local use.
    private func syncIfSignedIn() async {
        let auth = SupabaseAuthService.shared
        guard let client = auth.database, let userID = auth.userID else { return }
        let engine = SyncEngine(remote: SupabaseSyncRemote(client: client, userID: userID))
        try? await engine.syncNow(context: modelContainer.mainContext)
    }
}
