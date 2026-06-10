# GO-LIVE — wiring the three backend seams

This template ships a fully navigable app with **in-memory stubs** for the three
integrations that require a device or an App Store Connect account. Each is a
protocol the UI already depends on, so going live means **conforming a real
service and injecting it — no UI changes.**

| Seam | Protocol / entry point | Stub today | Real backend |
|---|---|---|---|
| 1. AR capture | `ARMeasureService` | `SimulatedARMeasureService` | ARKit / RealityKit + LiDAR |
| 2. Purchases | `PurchaseService` | `StubPurchaseService` | StoreKit 2 or RevenueCat |
| 3. Sign in | `AppState.completeAuth()` | direct call | AuthenticationServices |

> **Why stubs?** Real ARKit/AVFoundation capture, live StoreKit products, a real
> Sign-in-with-Apple backend, and an account-deletion endpoint all require a
> physical device and/or App Store Connect and **cannot be verified in the
> Simulator**. They are deliberately out of scope for the template and live here
> as the swap-in points.

---

## 1. AR capture — `ARMeasureService`

**File:** `Sources/Services/ARMeasureService.swift`

The protocol the Measure screens call:

```swift
@MainActor public protocol ARMeasureService: AnyObject {
    var lidarAvailable: Bool { get }
    var tracking: TrackingQuality { get }
    var targetDepthMeters: Double { get }
    var placedCount: Int { get }
    func start();  func stop()
    @discardableResult func placePoint() -> MeasurePoint
    func undo();   func finish()
}
```

`MeasureAView` / `MeasureBView` / `MeasureCView` take a `service:` in their init
(default `SimulatedARMeasureService`) and dispatch `start/stop/placePoint/undo/
finish`; they read `lidarAvailable` / `tracking` / `placedCount` for the HUD.

### To ship

1. Create `ARKitMeasureService: ARMeasureService` wrapping an `ARSession`.
   - **LiDAR path:** `ARWorldTrackingConfiguration` with
     `sceneReconstruction = .meshWithClassification` (gate on
     `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)`). Raycast
     against mesh anchors for `placePoint()`; set `lidarAvailable = true`.
   - **Fallback path:** when LiDAR is unsupported, use `planeDetection =
     [.horizontal, .vertical]` and raycast against detected planes; set
     `lidarAvailable = false`. The UI already renders the "VISUAL" fallback chip,
     banner, and ± precision copy off this flag.
2. Replace the SwiftUI `CameraBackdrop` stand-in with an `ARView` / camera feed.
3. Inject your service at the call sites (or via a small factory) instead of the
   default stub.
4. **Camera permission:** request `AVCaptureDevice.requestAccess(for: .video)` on
   the onboarding permission CTA (`OnbPermissionView`). The usage string
   (`NSCameraUsageDescription`) is already in `Info.plist`.

No capability needed beyond camera usage; ARKit links automatically.

---

## 2. Purchases — `PurchaseService`

**File:** `Sources/Screens/Rooms/PurchaseService.swift`

```swift
@MainActor public protocol PurchaseService: AnyObject {
    var plans: [SubscriptionPlan] { get }
    var defaultSelectionID: String { get }
    func purchase(_ plan: SubscriptionPlan) async -> PurchaseResult
    func restore() async -> PurchaseResult
}
```

`PaywallView` renders `plans` (Monthly / Annual `SAVE 58%` with a struck-through
`$59.88` anchor / Lifetime), calls `purchase`/`restore`, and on `.success` flips
`AppState.isPro = true` via `grantPro()`. Once Pro, the export quota meter and
paywall nudges hide and exports become unlimited (see `ExportView`).

### To ship (StoreKit 2)

1. Create the products in App Store Connect (matching the `SubscriptionPlan`
   ids: `Monthly`, `Annual`, `Lifetime`) and add the **In-App Purchase**
   capability.
2. Create `StoreKitPurchaseService: PurchaseService`:
   - `plans` ← map `Product` (from `Product.products(for:)`) → `SubscriptionPlan`
     (use `displayPrice` for `price`, derive `subtitle`/`tag`/`compareAt`).
   - `purchase(_:)` ← `try await product.purchase()`, verify the transaction,
     `await transaction.finish()`.
   - `restore()` ← `try await AppStore.sync()` then re-check entitlements.
   - Drive `isPro` from `Transaction.currentEntitlements` (don't trust a local
     flag) and listen to `Transaction.updates`.
3. **Or RevenueCat:** wrap `Purchases.shared`, map `Package`/`StoreProduct` →
   `SubscriptionPlan`, and read entitlements from `CustomerInfo`.
4. Inject your service into `PaywallView(service:)`.

The required **billing disclosure** (Guideline 3.1.2) is already computed
per-plan (`SubscriptionPlan.disclosure`), and the **Terms / Privacy** links open
the URLs in `LegalLinks` — replace those two URLs with your hosted EULA and
privacy policy before submitting.

---

## 3. Sign in — AuthenticationServices

**Files:** `Sources/Screens/Auth/SignInView.swift`, `Sources/App/AppState.swift`

Today the Apple/Google buttons and "Sign In" call `AppState.completeAuth()`
directly (advancing Auth → Onboarding), and "Forgot password?" shows a
confirmation alert. These are the auth seam.

### To ship (Sign in with Apple)

1. Add the **Sign in with Apple** capability/entitlement.
2. Replace the Apple `SocialButton` with `SignInWithAppleButton` (or use
   `ASAuthorizationController`), then on success exchange the identity token with
   your backend and call `completeAuth()`.
3. Wire "Forgot password?" and Create Account / Verify Code to your auth backend.
4. **Account deletion (Guideline 5.1.1(v)):** add a "Delete account" action in
   Settings that calls your backend's deletion endpoint. *(Out of scope for the
   template — needs a real backend; add before submission if you offer accounts.)*

---

## Out of scope (cannot be Simulator-verified)

- Real ARKit / AVFoundation camera capture
- Live StoreKit products / receipts
- Real Sign-in-with-Apple backend exchange
- Account-deletion endpoint

These require a physical device and/or App Store Connect. The seams above are
exactly where they plug in.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
