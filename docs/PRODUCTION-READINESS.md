# TapeScan — Production-Readiness Backlog

Generated from a multi-agent audit (63 raw issues → 8 P0 / 28 P1 / 22 P2 / 5 P3).
Status legend: ✅ done · 🔧 in progress · ⬜ todo · 👤 user/deployment action.

## P0 — release blockers

| # | Issue | Status |
|---|---|---|
| a | Global alert sits on RootView, behind every cover/sheet → Export/Paywall/Scan/Editor errors show nothing | ⬜ |
| b | Supabase unconfigured (placeholder URL/key) → Sign in with Apple, sync, account delete fail at runtime | 👤 create project + fill `SupabaseConfig.swift` before archive |
| c | Free export quota spent before share sheet → cancel still burns an export | ✅ |
| d | Export generation synchronous on main → UI freeze / force-quit | ✅ |
| e | Pro (MeasureCView) has NO place-point control → can't measure in Pro | ⬜ |
| f | finish() in B/C persisted nothing → measurements silently lost | ✅ (MeasureSession) |
| g | No crash-recovery autosave in B/C | ✅ (MeasureSession) |
| h | Tracking-degraded guidance computed but never shown in HUD | ⬜ |
| i | Sign-out/delete leak account A's synced data to account B on shared device | ✅ |
| j | Corrupt store → fatalError crash-loop on launch | ✅ (recovery) |

## P1 — important (28)

**Done ✅:** dead chevron rows (History + Settings Precision → read-only) · `NSPhotoLibraryAddUsageDescription` added · snap synced to B/C · no-surface feedback in B (via MeasureSession) · USDZ file cleanup on room delete · email OTP normalize+validate · resend clears stale code · permission re-check on foreground · empty/wall-less plan save guard · 1024 icon alpha flattened · release gate hard-fails on placeholder creds · editor keyboard Done + invalid-input feedback · success/place haptics. **Bonus:** AR warm-up loading overlay (user-requested).

**Also done ✅ (since):** launch-time LiDAR detection · sign-in-triggers-sync · "Measurement saved" success toast + haptics · delete confirmation (History + Rooms) · Pro area-label viewport clamp (defensive).

**Also done ✅ (since):** redo control in Precision + Minimal (undo/redo paired).

**Remaining ⬜ (features needing prioritization / device verification):**
- History rows have no detail screen (read-only + confirmed-delete is in place) — a new view.
- Editor: rename-room implemented in model but no UI affordance — new affordance.
- Empty/initial measure state (the reticle "ALIGN · TAP TO SET POINT" guidance already covers first-run; low value).
- App-icon set still declares iPad/Mac/Watch idioms (iPhone-only) — cosmetic (Xcode ignores them; alpha already fixed).
- Volume mode draws same overlay as area (niche, misleading geometry).

**Diagnosed — NOT a production bug:**
- Pro/area floor-readout renders top-left **in the Simulator only**: the simulated backend's seeded *projected* screen coords are degenerate (0,0), so the polygon centroid collapses to the origin. On device, `ARKitMeasureService` projects real screen coords, so the label positions correctly. Confirmed via instrumented screenshot (`g=402×874 p0=0,0`). (Optional: fix the simulated backend's seeded projections so previews/sim render the geometry, but it has no device impact.)

## P2/P3 — polish (27)

Misc accessibility + empty/error states, minor redraw optimizations, etc.

---
_Fixed this session (pre-audit): AR session single-owner lifecycle (freeze), RoomScan off-main coalesced live updates, floating Liquid Glass tab bar, reticle 1:1 alignment, bottom-bar clearance, all 3 Measure menus wired._
