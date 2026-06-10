# TapeScan — Competitive Benchmark & Scope Decisions

**Date:** 2026-06-10 · Derived from a 10-agent research sweep of the App Store
AR-measurement niche (AR Ruler & AR Plan 3D by Grymala, magicplan, Polycam,
RoomScan Pro, CamToPlan, Canvas/Occipital, Apple Measure, plus a category
landscape pass).

## Where TapeScan already wins (keep and market)

1. **One app for the whole pipeline** — measure + scan + parametric plan +
   export. Grymala splits this into two $89.99/yr subscriptions; Polycam gates
   floor plans at $400/yr Business.
2. **Trust pricing** — $24.99/yr sits below the $30–50 consumer anchor vs
   Grymala $89.99, magicplan $129.99+, RoomScan $119.99, Polycam $149.99–400.
   The $59.99 lifetime answers the niche's most-repeated request. 7-day trials
   vs the predatory 3-day norm. **No ads, no weekly SKUs, ever.**
3. **Optional accounts + offline-first sync** — unique in the niche. Grymala
   and CamToPlan have no cloud; Polycam forces accounts at launch (top
   complaint). "Your data is never hostage" is open whitespace.
4. **LiDAR + non-LiDAR fallback** — the 2025 wave of RoomPlan-wrapper apps is
   LiDAR-only.
5. **3D exports (USDZ + glTF) at consumer price** — Polycam charges
   $149.99/yr for pro 3D formats.

## Parity gaps adopted into v1 (scope changes)

| Addition | Effort | Lands in | Why |
|---|---|---|---|
| **DXF R12 export** (ASCII polylines + layers from plan geometry) | M | M6 | The format contractors open in AutoCAD; missing it brackets us as a toy. Every floor-plan competitor ships it. |
| **Auto-quantities panel** (perimeter, floor area, wall area net of openings, volume — on-screen + PDF) | S | M5/M6 | The actual job-to-be-done (paint/flooring math); pure arithmetic over data we already have. |
| **Incremental autosave + crash recovery** (measure sessions + scan results persisted within seconds) | S | M2/M5 | Every competitor loses work to crashes — their single most damaging review theme. "We never lose your scan." |
| **Live confidence indicator + published accuracy spec** (±1–2 cm LiDAR room-scale, ±2–5 cm fallback; warn in bad light/tracking) | S | M4 | No competitor publishes accuracy; silent wrong answers are their top trust killer. |
| **Fractional imperial** (ft′ in″ to 1/16″, persistent unit choice, sane auto-scaling) | S | M2 | Table stakes for US trades; competitors' unit bugs are credibility killers. |
| **Undo/redo** in measure mode | S | M2/M4 | Expected; magicplan's missing redo is a named gripe. |
| **CSV export** (measurements + room quantities) | S | M6 | Trivial; pads the export list comparison articles screenshot. |
| **Post-scan plan editor** (drag corners/walls, type exact lengths, add/remove doors & windows — 2D parametric only) | M | **new M10** | Converts every RoomPlan inaccuracy from a 1-star review into a 30-second fix. Best-in-class only in magicplan ($129/yr). |

## Reliability bar (hard rules, enforced across all milestones)

1. **No paywall or account prompt before the first successful measurement.**
   Rating prompt only after the 2nd successful export, never mid-capture.
2. **Disclose the 3-free-export limit BEFORE a scan starts** — never capture
   work and then ransom it. Created content stays viewable and re-openable
   forever regardless of payment state; lapsed subscribers lose only new
   exports/sync.
3. **Trial clarity:** exact post-trial price on the trial screen; one-tap
   manage-subscriptions. Never add weekly SKUs.
4. **Crash-safe by design:** sessions persisted incrementally; relaunch
   recovers drafts. Soak-test large rooms before launch.
5. **Never silently emit a wrong number:** confidence indicator + pre-capture
   warnings (low light, reflective surfaces, degraded tracking); reject
   nonsense outputs.
6. **Zero ads.** Explicit marketing line.

## Pricing verdict

Keep $4.99/mo · $24.99/yr · $59.99 lifetime exactly as designed — it is the
marketing. Lead with "no ads, no weekly subscription, your scans are never
held hostage." Future Pro tier (~$99/yr: IFC/Xactimate, DXF layers, multi-room
packs) rather than ever repricing the base. Watch lifetime cannibalization;
fix by raising lifetime later (grandfathered), never by weakening it.

## Deferred to v1.1 backlog (ordered)

1. Multi-room merge via RoomPlan StructureBuilder (stretch goal: pull into v1
   if device QA finishes early — clearest open gap at consumer price).
2. Read-only web share links for plans (Supabase storage + public viewer).
3. Bluetooth laser meter integration (Leica DISTO / Bosch GLM).
4. Pro export tier: IFC, Xactimate ESX, geo-tagged photo reports.
5. App Clip "measure without installing" (Grymala shipped May 2026).
6. Material/cost calculators on top of the quantities panel.
7. Photos + notes pinned to plan locations (insurance/property vertical).
8. Trades measure modes (heap/pit volume, curved walls, cylinders).
9. visionOS companion viewer (Apple-featuring magnet).
10. Free-export policy experiment: PDF/PNG-only free tier, renewably monthly.

## ASO notes (for M9)

- Don't fight Grymala for "ar ruler"/"tape measure" head terms; title-stack
  toward "room scan" + "floor plan" long-tail: name **TapeScan**, subtitle
  "AR Tape Measure & Floor Plan", keywords incl. "lidar room scanner floor
  plan", "room planner".
- Category: Utilities (CamToPlan's slot; Productivity is Grymala-crowded).
- Apple actively features RoomPlan-powered apps ("Renovate and Decorate Your
  Home" editorial) — polish scan UX and pitch post-launch.
