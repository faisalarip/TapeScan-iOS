# TapeScan — AR Tape Measure & Floor Plan (iOS)

Native SwiftUI app: ARKit multi-point measuring (distance / area / volume /
angle, LiDAR + visual fallback), RoomPlan room scanning → parametric floor
plans, exports (PDF / PNG / SVG / DXF / CSV / USDZ / glTF), optional Supabase
accounts with offline-first sync, StoreKit 2 Pro subscription.

Bundle: `co.tuntun.tapescan` · iOS 17+ · iPhone (room scan needs LiDAR).
Legal/support pages: https://faisalarip.github.io/tapescan-legal/

## Build & run

```bash
brew install xcodegen            # once
xcodegen generate                # after adding/removing files
open TapeMeasureARPro.xcodeproj  # scheme: TapeScan → iPhone 17 Pro simulator
```

Command line:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

The Simulator runs end-to-end with a simulated AR backend, a scripted room
scan, and the local `TapeScan.storekit` configuration (purchases testable
without App Store Connect). Real ARKit/RoomPlan run on device only.

## Architecture

| Layer | Where | Notes |
|---|---|---|
| Domain math & models | `Sources/Domain/` | Pure, fully unit-tested (MeasureMath, FloorPlanModel + quantities, CapturedRoomConverter) |
| Services | `Sources/Services/` | AR seam (`ARMeasureService` protocol → simulated/ARKit), RoomPlan scan, StoreKit 2, Supabase auth, SyncEngine, exporters |
| Persistence | `Sources/Persistence/` | SwiftData records w/ sync bookkeeping, crash-recovery session drafts |
| UI | `Sources/Screens/`, `Components/`, `Theme/` | Design-system theming, Dynamic Type via UIFontMetrics, Reduce Motion gates |

Key invariants:

- **isPro is never stored** — derived from `Transaction.currentEntitlements`
  (launch + `Transaction.updates` listener in `TapeMeasureARProApp`).
- **Accounts never gate the app** — sign-in is an optional, dismissible sheet;
  sync failures are silent; deleting the account keeps local data.
- **No silent wrong numbers** — raycasts >15 m are rejected; tracking
  degradation surfaces guidance strings in the HUD.
- **Crash-safe capture** — measure sessions autosave per change
  (`SessionDraftStore`); scans persist immediately on completion.

## Owner inputs before release

1. `DEVELOPMENT_TEAM` in `project.yml` (+ flip `CODE_SIGNING_ALLOWED`).
2. Supabase project: apply `supabase/migrations/0001_init.sql`, fill
   `Sources/Services/SupabaseConfig.swift`.
3. App Store Connect app record + the 3 IAPs (`tapescan.pro.monthly`,
   `tapescan.pro.annual`, `tapescan.pro.lifetime`) — see `docs/ASC-SETUP.md`
   (M9).

## Tests

`TapeScanTests` (unit: math, formatters, converters, exporters, sync merge,
product mapping, persistence) and `TapeScanUITests` (launch smoke). All
DEBUG-only launch args (`-uiPhase`, `-uiTab`, `-uiPro`, `-uiPaywall`,
`-uiFreeExports`, `-uiMeasureDir`) are compiled out of Release.

Design history & specs live in `docs/superpowers/`.
