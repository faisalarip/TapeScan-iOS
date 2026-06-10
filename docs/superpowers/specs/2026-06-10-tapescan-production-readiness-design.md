# TapeScan v1 — Production Readiness Design

**Date:** 2026-06-10
**Status:** Approved by owner (all 9 sections)
**Goal:** Take the TapeMeasureARPro white-label template from a Simulator-only UI prototype to a real, App-Store-submittable product named **TapeScan**.

## Decisions log (locked with owner)

| Decision | Choice |
|---|---|
| App name / bundle ID | **TapeScan** / `co.tuntun.tapescan` |
| Overall approach | Full native: ARKit measuring + Apple RoomPlan room scan |
| Purchases | StoreKit 2 native (no RevenueCat) |
| Accounts | Optional (skippable) via Supabase; never gates app use |
| Auth methods | Sign in with Apple (native), Google (Supabase OAuth), email OTP |
| Cloud sync | Full sync of measurements + rooms in v1, offline-first |
| 3D export | USDZ (from RoomPlan) **and** custom glTF exporter |
| Legal pages | Generated privacy policy + terms, hosted on GitHub Pages |
| Verification hardware | Owner has LiDAR iPhone + paid Apple Developer account |
| Pricing (unchanged) | Monthly $4.99 / Annual $24.99 (7-day trials) / Lifetime $59.99 |
| Shipped HUD style | "Precision" (MeasureAView); style picker becomes DEBUG-only |

## Current state (audit summary, 2026-06-10)

Builds clean on Xcode 26.1.1 (6 cosmetic warnings). UI shell, theming, and
navigation are production-quality. **Every functional system is simulated:**
no ARKit/AVFoundation/StoreKit/AuthenticationServices imports exist anywhere;
all measurements are hardcoded design literals; exports write no files;
purchases and auth unconditionally succeed; nothing persists across launches;
no error UI exists; `PaywallView` crashes on an empty plans array
(`service.plans[0]`); no git repo, no tests, no entitlements, signing disabled.
Submitting as-is is a certain Guideline 2.1 rejection. Full audit findings live
in the workflow output referenced by the session transcript.

---

## 1. Identity & project foundation

- Rename product to **TapeScan**: `CFBundleDisplayName`, bundle ID
  `co.tuntun.tapescan`, target/scheme names in `project.yml`; regenerate with
  XcodeGen. Default `AppState.brand` becomes "TapeScan" (single source; remove
  duplicated literals in `SettingsView.swift` and `OnbWelcomeView.swift`).
- Version control: `git init`, `.gitignore` (xcuserdata, .build, .DS_Store),
  initial commit of audited state; commit at each milestone.
- Signing: `DEVELOPMENT_TEAM` from owner, automatic signing,
  `TapeScan.entitlements` with In-App Purchase + Sign in with Apple
  (`com.apple.developer.applesignin`).
- Shared scheme committed under `xcshareddata/xcschemes`.
- Info.plist: add `ITSAppUsesNonExemptEncryption=false`,
  `UIRequiredDeviceCapabilities=[arkit]`; replace invalid
  `UIUserInterfaceStyleDefault` with `UIUserInterfaceStyle=Dark`; remove inert
  `UIStatusBarStyle`.
- Fix the 6 `DRow` trailing-closure deprecation warnings in `SettingsView.swift`.
- DEBUG-fence the white-label surfaces: brand-name field (Settings) and the
  3-way HUD style picker (Measure). Accent color picker stays user-facing as
  personalization.

## 2. AR measurement engine

**New protocol shape** (replaces the too-thin `ARMeasureService`):

- `MeasurePoint` becomes a 3D world-space point (`simd_float3` + stable id);
  the service publishes per-frame **projected screen coordinates** so the
  existing `MeasureScene` SwiftUI overlay renders real geometry in the current
  visual style.
- Service exposes: `lidarAvailable` (from
  `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)`),
  `tracking` (mapped from `ARCamera.trackingState`), placed points, computed
  `MeasureResult` for the active mode, `start/stop/placePoint/undo/finish`,
  and mode selection (distance / area / volume / angle). Service is
  `@Observable` so views react instead of manually re-reading.

**Implementations:**

- `ARKitMeasureService`: owns an `ARSession` hosted in a RealityKit `ARView`
  wrapped in `UIViewRepresentable` (`ARViewContainer`), which replaces
  `CameraBackdrop` on device. LiDAR path: `sceneReconstruction = .mesh`,
  raycast against mesh. Fallback path: horizontal+vertical plane detection,
  raycast `.estimatedPlane`. Anchors keep points world-stable.
- `SimulatedARMeasureService` retained for Simulator builds and previews,
  conforming to the new protocol (now with plausible moving values), selected
  via `#if targetEnvironment(simulator)` factory.

**Math:** pure `MeasureMath` module, fully unit-tested: segment/polyline
distance, polygon area via shoelace on the best-fit plane, prism volume
(base area x height point), angle at vertex. All UI readouts flow from
`MeasureResult` through the existing `UnitFormat` — no literals remain.

**Permission & lifecycle:** onboarding CTA calls
`AVCaptureDevice.requestAccess(.video)`; denial state shows a Settings
deep-link. `scenePhase` observation pauses/resumes the session.
`finish()` persists a `Measurement` (section 5) and resets the session.

**Honest UI:** LiDAR/precision chips and Settings "LiDAR depth" row become
read-only hardware status. "Point snapping" becomes a real setting (new
points snap to existing points within a small world-space threshold, which
also closes polygons cleanly); the "Plane detection" toggle is removed
(plane detection is not optional in the fallback path). The fake "REC"
indicator is removed.

## 3. Room scan & floor plan

- `RoomScanService` wraps **RoomPlan** `RoomCaptureSession` (custom UI via
  `RoomCaptureView` representable), mapping live `CapturedRoom` updates onto
  the existing scan UI (real coverage %, wall count, area).
- `FloorPlanModel` (Codable, parametric): walls, doors, windows, openings,
  room polygons, dimensions — derived from `CapturedRoom` by a unit-tested
  converter. The `FloorPlan` view is refactored to render any
  `FloorPlanModel` in its current visual style; the hardcoded demo apartment
  is deleted.
- Non-LiDAR devices: Rooms tab shows a "Room scan requires a LiDAR-equipped
  iPhone" state; measuring remains available.

## 4. Exports

From a saved room's `FloorPlanModel` / `CapturedRoom`:

- **PDF** — `UIGraphicsPDFRenderer`, dimensioned plan with labels.
- **PNG** — `ImageRenderer` of the plan view at 3x.
- **SVG** — string generation from the model (unit-tested output).
- **USDZ** — `CapturedRoom.export(to:)` (RoomPlan built-in).
- **glTF** — custom exporter building wall/door/window boxes from the
  parametric model (validated against the Khronos glTF validator in tests).

Delivery via system share sheet. Files written to a temp directory and cleaned
up. Free quota (3 exports) persists in `@AppStorage`; Pro removes the gate.
Fix the existing bug where Pro users' export button is a silent no-op.
Paywall perk copy updated to match reality ("USDZ + glTF 3D export").

## 5. Local persistence

- **SwiftData** models:
  - `Measurement`: mode, name, 3D points, computed values, createdAt,
    updatedAt, remoteID, deletedAt (tombstone).
  - `Room`: name, `FloorPlanModel` (Codable blob), captured-room archive,
    area, createdAt, updatedAt, remoteID, deletedAt.
- Settings → `@AppStorage`: unit, accent, density, hasOnboarded, free-export
  count. Privacy manifest gains `NSPrivacyAccessedAPICategoryUserDefaults`
  with reason `CA92.1`.
- `isPro` is **derived state** from `Transaction.currentEntitlements` — never
  persisted as a flag.
- History tab reads real `Measurement`/`Room` queries with empty states;
  seeded fixtures deleted; rows open a detail/rename/delete affordance.

## 6. Purchases (StoreKit 2)

- Product IDs: `tapescan.pro.monthly` ($4.99/mo, 7-day trial),
  `tapescan.pro.annual` ($24.99/yr, 7-day trial),
  `tapescan.pro.lifetime` ($59.99 non-consumable).
- `StoreKitPurchaseService: PurchaseService`: loads via
  `Product.products(for:)`; maps to `SubscriptionPlan` using localized
  `displayPrice`; computes the savings tag from real prices; `purchase()`
  verifies + finishes transactions; `restore()` = `AppStore.sync()` +
  entitlement re-check; a `Transaction.updates` listener keeps `isPro` live.
- Paywall hardening: loading state while products fetch; explicit
  empty/error state (eliminates the `plans[0]` crash); alert on `.failed`;
  `.cancelled` is silent. Trial copy shown only when the introductory offer
  is actually present on the product.
- Settings additions: Restore Purchases, Manage Subscription
  (`showManageSubscriptions`), Terms/Privacy links, app version row, and
  (when signed in) Sign out + Delete account.
- Local testing via a committed StoreKit configuration file; sandbox testing
  on the owner's device. Owner creates the app + products in App Store
  Connect following a step-by-step doc we provide (`docs/ASC-SETUP.md`).

## 7. Auth & sync (Supabase, optional accounts)

**Gating change:** `AppState.phase` drops the auth gate — first launch goes
onboarding → main. Sign-in is offered once post-onboarding (skippable) and
forever after via Settings ("Back up & sync"). All features work signed out.

**Auth (supabase-swift SDK):**

- Apple: native `ASAuthorizationController` with nonce →
  `auth.signInWithIdToken(.apple)`.
- Google: Supabase OAuth via `ASWebAuthenticationSession`.
- Email: `signInWithOTP` → existing `VerifyCodeView` verifies the real code
  (pre-seeded "4821" and demo identity strings removed; resend actually
  resends). Forgot-password flow removed in favor of OTP login (no passwords
  stored at all) — Create Account and Sign In collapse into one email flow.
- Sign in with Apple capability added; Google OAuth client configured in
  Supabase dashboard.

**Schema (Postgres, owner-only RLS on every table):**

- `profiles(id uuid PK -> auth.users, created_at)`
- `measurements(id uuid PK, user_id, payload jsonb, updated_at timestamptz, deleted_at timestamptz)`
- `rooms(id uuid PK, user_id, payload jsonb, updated_at timestamptz, deleted_at timestamptz)`

**Sync engine (offline-first):** SwiftData is the source of truth. Push queue
on local change; pull on launch/foreground/sign-in. Conflict resolution:
last-write-wins on `updated_at`; deletes via tombstones, purged after sync.
Sync failures surface as a passive status line, never block local use.

**Account deletion (5.1.1(v)):** Settings → confirm dialog → Supabase
RPC/edge function deletes the auth user + cascaded rows → local sign-out
(local data retained unless the user also chooses "erase local data").

## 8. Compliance, accessibility & polish

- **Legal:** generate an app-specific privacy policy + terms; publish as a
  static GitHub Pages site; update `LegalLinks`; make the signup "Terms /
  Privacy Policy" text actual links; same URLs go into App Store Connect.
- **Dynamic Type:** `Theme.sans()/mono()` switch to
  `Font.system(..., relativeTo:)` text styles; spot-check large sizes for
  clipping on Paywall, Measure HUD, Settings.
- **Reduce Motion:** gate the four `repeatForever` animations (Reticle,
  StatusDot, CameraBackdrop sweep, VerifyCode caret) on
  `accessibilityReduceMotion`.
- **Error surface:** one lightweight alert/toast mechanism used by purchase,
  auth, sync, export, and AR-session failures.
- **Privacy manifest + ASC nutrition labels:** declare collected data
  truthfully — email (Contact Info), user content (measurements/rooms),
  purchase history, identifiers (user ID) — collection linked to identity,
  no tracking. "Frames never leave your device" stays (and stays true).
- Replace README/GO-LIVE template docs with real project docs.

## 9. QA & release

- **Unit tests** (new test target): `MeasureMath`, `UnitFormat`,
  CapturedRoom→FloorPlanModel converter, SVG/glTF generators, sync merge
  (LWW + tombstones), plan-mapping for StoreKit products.
- **UI smoke tests** (XCUITest) riding the existing `-uiPhase/-uiTab/-uiPro`
  launch args: onboarding flow, paywall render, settings, history empty state.
- **Builds:** Debug + Release compile in CI-style script; archive verified.
- **On-device checklist** for the owner: tape-measure accuracy vs a physical
  tape (target ±1cm LiDAR), room scan of a real room, all 4 export formats
  open correctly, sandbox purchase/restore/trial, all three sign-in methods,
  sync across reinstall, account deletion, permission-denied recovery.
- **ASC submission package:** description, subtitle ("AR Tape Measure &
  Floor Plan"), keywords, category (Utilities), age rating answers (4+),
  screenshot plan (6.9" + 6.5"), support URL (GitHub Pages site), review
  notes explaining LiDAR requirement for room scan + demo video if asked.
  No demo account needed since accounts are optional.

## Out of scope for v1

- iPad layout (`TARGETED_DEVICE_FAMILY=1` stays iPhone-only)
- Localization beyond English (structure strings for it where cheap)
- Watermarking system, measurement photo attachments, Android/web

## Owner inputs needed (non-blocking to start)

1. Apple Team ID (for signing).
2. ~15 min in App Store Connect to create the app record + 3 IAP products
   (guided by `docs/ASC-SETUP.md`).
3. A GitHub repo for the legal/support pages (or permission to create one).
4. Go-ahead to create the Supabase project (free tier).
