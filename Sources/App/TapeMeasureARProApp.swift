// TapeMeasureARProApp.swift — SwiftUI App entry point.

import SwiftUI
import SwiftData
import ARKit
import GoogleSignIn
// Firebase is OPTIONAL: the project must compile with ZERO SDK present, so the
// import is gated on canImport. When the owner adds the FirebaseAnalytics SPM
// package (which pulls FirebaseCore) this lights up; until then it's a no-op.
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct TapeMeasureARProApp: App {
    /// Root-owned application state, injected into the environment.
    @State private var appState = AppState.bootstrapped()
    /// The on-disk SwiftData store (measurements + rooms).
    private let modelContainer = ModelContainerFactory.make()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Configure Firebase as early as possible (App init runs before any
        // scene/view). Guarded so the app builds without the SDK. This is safe
        // to call here because FirebaseAnalyticsService.init() never touches
        // Firebase — collection is only toggled later from the root `.task`
        // (and the analyticsOptOut didSet), AFTER this configure() has run.
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
                // Route OAuth redirects (Google native sign-in) to the SDK.
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
                .task {
                    // Detect real LiDAR capability at launch so the precision badge
                    // + Settings reflect THIS device before the Measure tab is ever
                    // opened (previously defaulted true until Measure's onAppear ran).
                    #if targetEnvironment(simulator)
                    appState.lidar = true
                    #else
                    appState.lidar = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
                    #endif

                    // Restore any signed-in session, then sync.
                    await SupabaseAuthService.shared.loadSession()
                    appState.isAuthenticated = SupabaseAuthService.shared.userID != nil
                    await syncIfSignedIn()

                    // isPro is DERIVED state: checked from StoreKit entitlements
                    // at launch, then kept current by the transaction listener
                    // (renewals, Ask-to-Buy approvals, refunds). Never stored.
                    appState.isPro = await StoreKitPurchaseService.currentEntitlementIsPro()

                    // ── Analytics bootstrap ───────────────────────────────────
                    // Runs AFTER the entitlement check so the seeded user
                    // properties + first app_open carry an accurate is_pro.
                    // startSession() bumps sessionCount and stamps firstOpenAt
                    // once (powers sessions/time-to-convert attribution).
                    appState.attribution.startSession(now: Date())
                    // Apply the persisted opt-out and turn collection on/off.
                    // (FirebaseApp.configure() already ran in init(); this is the
                    // first point we touch Firebase.) No-op when SDK is absent.
                    appState.analytics.start(collectionEnabled: !appState.analyticsOptOut)
                    // Seed user properties (closed enum, no PII).
                    appState.analytics.setUserProperty(appState.isPro ? "true" : "false", for: .isPro)
                    appState.analytics.setUserProperty(appState.lidar ? "true" : "false", for: .lidar)
                    appState.analytics.setUserProperty(appState.hasOnboarded ? "true" : "false", for: .onboardingCompleted)
                    appState.analytics.setUserProperty(appState.analyticsOptOut ? "true" : "false", for: .analyticsOptOut)
                    // First event of the cold start.
                    appState.analytics.log(AnalyticsEventName.appOpen, [
                        AnalyticsParam.isPro: .bool(appState.isPro),
                        AnalyticsParam.lidar: .bool(appState.lidar),
                    ])

                    // Out-of-band entitlement changes (renewals, Ask-to-Buy
                    // approvals, refunds) arrive here with no live paywall
                    // source. We log subscription_status_change attributed to
                    // the persisted conversionSource — and NEVER the GA4
                    // `purchase` event, which would inflate new-conversion
                    // revenue (Firebase auto-handles recurring revenue).
                    await StoreKitPurchaseService.listenForTransactionUpdates { isPro, productID, isRefund in
                        appState.isPro = isPro
                        appState.analytics.setUserProperty(isPro ? "true" : "false", for: .isPro)
                        appState.analytics.log(AnalyticsEventName.subscriptionStatusChange, [
                            AnalyticsParam.changeType: .string(isRefund ? "refund" : "renewal_or_purchase"),
                            AnalyticsParam.productId: .string(productID),
                            AnalyticsParam.planKind: .string(PlanKind.from(productID: productID)),
                            AnalyticsParam.source: .string(appState.attribution.conversionSource ?? "out_of_band"),
                        ])
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
