# TapeScan — Architecture Contracts (canonical)

These are the **canonical shared types, protocols, and file locations** for the
TapeScan v1 implementation. Every milestone plan MUST use these exact names and
signatures. If a plan needs to deviate, the deviation must be made here first.

Parent spec: `2026-06-10-tapescan-production-readiness-design.md`

## Milestones & dependencies

| # | Plan | Depends on | Verifiable in Simulator? |
|---|------|-----------|--------------------------|
| M1 | Foundation & identity | — | yes |
| M2 | Domain models, math & persistence | M1 | yes (unit tests) |
| M3 | StoreKit 2 purchases | M1, M2 | yes (StoreKit config file) |
| M4 | AR measurement engine | M2 | partially (device for AR) |
| M5 | RoomPlan scan & floor plan | M2 | partially (device for scan) |
| M6 | Exports | M2 (fixtures), M5 (real data) | yes (fixture models) |
| M7 | Supabase auth & sync | M2 | yes |
| M8 | Compliance, a11y & polish | M3, M7 | yes |
| M9 | QA, release & ASC package | all | partially |

## Project identity (M1)

- Bundle ID: `co.tuntun.tapescan` · Display name: `TapeScan`
- Target/scheme: `TapeScan` (renamed in `project.yml`, regenerate via `xcodegen generate`)
- Entitlements file: `Sources/Resources/TapeScan.entitlements`
  (In-App Purchase, `com.apple.developer.applesignin` = Default)
- Test targets: `TapeScanTests` (unit), `TapeScanUITests` (XCUITest), defined in `project.yml`

## Directory layout (new code)

```
Sources/Domain/        MeasureTypes.swift, MeasureMath.swift,
                       FloorPlanModel.swift, CapturedRoomConverter.swift
Sources/Persistence/   MeasurementRecord.swift, RoomRecord.swift,
                       ModelContainerFactory.swift
Sources/Services/      ARMeasureService.swift (protocol + simulated, existing file),
                       ARKitMeasureService.swift, RoomScanService.swift,
                       PurchaseService.swift (moved from Screens/Rooms),
                       StoreKitPurchaseService.swift,
                       AuthService.swift, SupabaseAuthService.swift,
                       SyncEngine.swift,
                       Export/ExportService.swift, Export/PDFExporter.swift,
                       Export/SVGExporter.swift, Export/GLTFExporter.swift
Tests/TapeScanTests/   one file per Domain/Service unit under test
Tests/TapeScanUITests/ SmokeTests.swift
```

## Measurement domain (M2; consumed by M4, M5, M7)

```swift
// Sources/Domain/MeasureTypes.swift
public enum MeasureMode: String, Codable, CaseIterable, Sendable {
    case distance, area, volume, angle
}

public struct WorldPoint: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var x: Float, y: Float, z: Float      // world space, meters
    public var position: SIMD3<Float> { .init(x, y, z) }
    public init(id: UUID = UUID(), position: SIMD3<Float>)
}

public struct ProjectedPoint: Identifiable, Equatable, Sendable {
    public let id: UUID            // matches WorldPoint.id
    public var screen: CGPoint     // view coordinates
    public var isVisible: Bool     // false when behind camera
}

public struct MeasureResult: Codable, Equatable, Sendable {
    public var mode: MeasureMode
    public var segmentLengths: [Double]   // meters, in placement order
    public var totalLength: Double        // meters
    public var area: Double?              // m² (area & volume modes)
    public var volume: Double?            // m³ (volume mode)
    public var angleDegrees: Double?      // angle mode: angle at middle vertex
}

public enum TrackingQuality: Equatable, Sendable {
    case initializing, normal, limited(reason: String), notAvailable
}
```

```swift
// Sources/Domain/MeasureMath.swift — pure functions, fully unit-tested
public enum MeasureMath {
    public static func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Double
    public static func polylineLength(_ pts: [SIMD3<Float>]) -> Double
    /// Shoelace area of `pts` projected onto their best-fit plane. ≥3 points.
    public static func polygonArea(_ pts: [SIMD3<Float>]) -> Double
    /// Prism volume: polygonArea(base) × |height of apex above base plane|.
    public static func prismVolume(base: [SIMD3<Float>], apex: SIMD3<Float>) -> Double
    /// Angle ABC in degrees at vertex B.
    public static func angleDegrees(a: SIMD3<Float>, vertex: SIMD3<Float>, c: SIMD3<Float>) -> Double
    /// Snap `candidate` to the nearest of `existing` within `threshold` meters; nil if none.
    public static func snap(_ candidate: SIMD3<Float>, to existing: [SIMD3<Float>], threshold: Float) -> SIMD3<Float>?
    /// Aggregates points into a MeasureResult for the mode.
    public static func result(mode: MeasureMode, points: [SIMD3<Float>]) -> MeasureResult
}
```

## AR service protocol (M2 redefines; M4 implements)

The existing `ARMeasureService` protocol in `Sources/Services/ARMeasureService.swift`
is **replaced** by:

```swift
@MainActor public protocol ARMeasureService: AnyObject, Observable {
    var lidarAvailable: Bool { get }          // real hardware capability
    var tracking: TrackingQuality { get }
    var mode: MeasureMode { get set }
    var snapEnabled: Bool { get set }
    var points: [WorldPoint] { get }
    var projected: [ProjectedPoint] { get }   // refreshed every frame
    var result: MeasureResult { get }         // recomputed on point changes
    var targetDepthMeters: Double? { get }    // depth at reticle, nil pre-tracking
    func start()
    func stop()
    @discardableResult func placePoint() -> WorldPoint?  // nil if raycast missed
    func undo()
    /// Returns the final result (for persistence) and clears session points.
    @discardableResult func finish() -> MeasureResult?
}
```

- `SimulatedARMeasureService` (same file) conforms, with plausible animated
  values; selected via `MeasureServiceFactory.make()` which returns the
  simulated service `#if targetEnvironment(simulator)` and
  `ARKitMeasureService` otherwise.
- `ARKitMeasureService` (M4) hosts `ARSession` through `ARViewContainer`
  (`UIViewRepresentable` around RealityKit `ARView`) replacing `CameraBackdrop`
  in Measure screens on device. Views keep reading the same protocol.

## Floor plan domain (M2 types; M5 converter; M6 consumers)

```swift
// Sources/Domain/FloorPlanModel.swift — all coordinates in METERS, plan space
public struct FloorPlanModel: Codable, Equatable, Sendable {
    public struct Wall: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public var startX: Double, startY: Double, endX: Double, endY: Double
        public var thickness: Double                    // meters, default 0.12
    }
    public enum OpeningKind: String, Codable, Sendable { case door, window, opening }
    public struct Opening: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public var kind: OpeningKind
        public var wallID: UUID
        public var offset: Double      // meters along wall from start
        public var width: Double       // meters
    }
    public struct RoomArea: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public var label: String                       // "ROOM 1" default
        public var polygonX: [Double], polygonY: [Double]
        public var areaSquareMeters: Double
    }
    public var walls: [Wall]
    public var openings: [Opening]
    public var rooms: [RoomArea]
    public var widthMeters: Double     // bounding box
    public var heightMeters: Double
    public var capturedAt: Date
}
```

- `CapturedRoomConverter.convert(_ room: CapturedRoom) -> FloorPlanModel`
  (M5): projects RoomPlan walls/doors/windows to 2D plan space, normalized so
  min corner = (0,0).
- `FloorPlan` SwiftUI view (existing `Sources/Components/FloorPlan.swift`) is
  refactored in M5 to `FloorPlan(model: FloorPlanModel, unit: MeasureUnit)`.
- A fixture `FloorPlanModel.sample` (M2, in `FloorPlanModel.swift` behind
  `#if DEBUG`) reproduces today's demo apartment for previews/tests/M6 dev.

## Persistence (M2; consumed by M4–M7)

```swift
// Sources/Persistence/MeasurementRecord.swift
@Model public final class MeasurementRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var modeRaw: String                 // MeasureMode.rawValue
    public var pointsData: Data                // JSONEncoder([WorldPoint])
    public var resultData: Data                // JSONEncoder(MeasureResult)
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?                // tombstone for sync
    public var remoteSyncedAt: Date?           // nil = never pushed
}

// Sources/Persistence/RoomRecord.swift
@Model public final class RoomRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var planData: Data                  // JSONEncoder(FloorPlanModel)
    public var usdzFilename: String?           // file in Application Support/Rooms/
    public var areaSquareMeters: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var remoteSyncedAt: Date?
}

// Sources/Persistence/ModelContainerFactory.swift
public enum ModelContainerFactory {
    public static func make() -> ModelContainer          // on-disk
    public static func makeInMemory() -> ModelContainer  // tests/previews
}
```

- Settings move to `@AppStorage` keys: `"unit"`, `"accent"`, `"density"`,
  `"hasOnboarded"`, `"freeExportsLeft"` (Int, default 3), `"snapEnabled"`.
  `AppState` reads/writes these via plain `UserDefaults` in `didSet` (it is
  `@Observable`, not `ObservableObject`, so `@AppStorage` property wrappers
  don't apply inside it).
- History/Rooms tabs query SwiftData (`@Query`); seed fixtures deleted.

## Error surface (M2; used everywhere)

```swift
// In AppState
public struct AppAlert: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var message: String
    public init(title: String, message: String)
}
// AppState gains: var alert: AppAlert?
// RootView attaches: .alert(item: $appState.alert) { ... } (single global alert)
```

## Purchases (M3)

- Product IDs: `tapescan.pro.monthly`, `tapescan.pro.annual`,
  `tapescan.pro.lifetime`.
- `PurchaseService` protocol moves to `Sources/Services/PurchaseService.swift`
  and becomes:

```swift
public enum PurchaseLoadState: Equatable {
    case loading, loaded, failed(String)
}

@MainActor public protocol PurchaseService: AnyObject, Observable {
    var loadState: PurchaseLoadState { get }
    var plans: [SubscriptionPlan] { get }      // empty until loaded
    var defaultSelectionID: String { get }
    func loadProducts() async
    func purchase(_ plan: SubscriptionPlan) async -> PurchaseResult
    func restore() async -> PurchaseResult
}
```

- `SubscriptionPlan`/`PurchaseResult`/`LegalLinks` keep their existing shapes;
  `SubscriptionPlan.id` becomes the product ID; display strings come from
  StoreKit (`displayPrice`, computed savings tag).
- `StoreKitPurchaseService` also exposes
  `static func currentEntitlementIsPro() async -> Bool` and runs a
  `Transaction.updates` listener task that sets `AppState.isPro`.
- `AppState.isPro` remains the UI mirror, set ONLY from entitlement checks
  (launch + updates listener + post-purchase/restore). `grantPro()` is deleted.
- StoreKit configuration file: `TapeScan.storekit` at repo root, referenced by
  the shared scheme for Simulator testing.
- Legal URLs: `LegalLinks.terms` / `.privacy` point to the GitHub Pages site
  (M8 publishes; M3 uses final URLs:
  `https://<owner-gh-username>.github.io/tapescan-legal/terms.html` and
  `.../privacy.html` — placeholder host until owner supplies the repo, tracked
  as an M8 input).

## Auth & sync (M7)

```swift
// Sources/Services/AuthService.swift
@MainActor public protocol AuthService: AnyObject, Observable {
    var userID: UUID? { get }                  // nil = signed out / guest
    var userEmail: String? { get }
    func signInWithApple(idToken: String, nonce: String) async throws
    func signInWithGoogle() async throws        // ASWebAuthenticationSession OAuth
    func sendEmailOTP(to email: String) async throws
    func verifyEmailOTP(email: String, code: String) async throws
    func signOut() async throws
    func deleteAccount() async throws           // server-side delete + local signOut
}
```

- `SupabaseAuthService` implements via `supabase-swift` (SPM dependency,
  pinned major 2.x). Supabase URL + anon key live in `Sources/Resources/
  SupabaseConfig.swift` (checked in; anon key is public by design).
- `AppState` changes: `phase` drops `.auth` gating (onboarding → main);
  `isAuthenticated` is derived (`authService.userID != nil`); sign-in becomes
  a sheet offered post-onboarding (skippable) and from Settings.
- Supabase schema (SQL migration committed under `supabase/migrations/`):

```sql
create table public.measurements (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null,
  deleted_at timestamptz
);
create table public.rooms (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null,
  deleted_at timestamptz
);
-- RLS: enable on both; policy: user_id = auth.uid() for select/insert/update/delete
```

- Account deletion: SECURITY DEFINER function `delete_user()` that deletes
  `auth.users` row (cascades wipe data), called via RPC.
- `SyncEngine` (actor): `func syncNow(context: ModelContext) async` —
  push local records where `remoteSyncedAt == nil || updatedAt > remoteSyncedAt`
  (upsert by id), pull remote where `updated_at > lastPulledAt` (stored in
  UserDefaults key `"lastPulledAt"`), conflict = last-write-wins on
  `updatedAt`, tombstoned rows deleted locally after applying. Triggered on:
  app foreground, sign-in, and local save (debounced 2 s). Failures set a
  passive status, never an alert.

## Export (M6)

```swift
// Sources/Services/Export/ExportService.swift
public enum ExportFormat: String, CaseIterable { case pdf, png, svg, usdz, gltf }

public enum ExportError: Error, Equatable { case notPro(quotaExhausted: Bool), generationFailed(String) }

@MainActor public final class ExportService {
    /// Writes the export to a temp URL ready for the share sheet.
    public func export(room: RoomRecord, format: ExportFormat) throws -> URL
}
```

- PDF via `UIGraphicsPDFRenderer`, PNG via `ImageRenderer` (3x), SVG via
  `SVGExporter.svg(for: FloorPlanModel) -> String`, glTF via
  `GLTFExporter.gltf(for: FloorPlanModel) -> Data` (single .gltf JSON with
  embedded base64 buffer; walls/doors extruded to 2.4 m default height),
  USDZ by copying the stored RoomPlan export file.
- Quota: `freeExportsLeft` decremented only on successful non-Pro export;
  Pro = unlimited (and the silent-no-op bug is fixed: Pro exports actually run).

## DEBUG fences (M1, M8)

- Brand-name field, HUD style picker: wrapped in `#if DEBUG`.
- All existing `-ui*` launch args stay DEBUG-only; M9's UITests use them.

## Commit conventions

Conventional commits (`feat:`, `fix:`, `test:`, `chore:`, `docs:`), one commit
per plan step group, always ending with the standard co-author trailer.
