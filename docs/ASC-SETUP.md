# TapeScan — App Store Connect setup (M9)

Everything you type into App Store Connect, prepared. Budget ~15 minutes.
Prerequisite: Apple Developer Program membership active.

## 1. App record

**App Store Connect → Apps → ＋ → New App**

| Field | Value |
|---|---|
| Platform | iOS |
| Name | **TapeScan** |
| Primary language | English (U.S.) |
| Bundle ID | `com.faisalnurarif.tapescan` (register it under Certificates → Identifiers first, with **In-App Purchase** + **Sign in with Apple** capabilities) |
| SKU | `tapescan-001` |

## 2. App Information

- Subtitle: **AR Tape Measure & Floor Plan**
- Category: **Utilities** (secondary: Productivity)
- Content rights: does not contain third-party content.
- Age rating questionnaire: answer **No** to everything → **4+**.
- Privacy Policy URL: `https://faisalarip.github.io/tapescan-legal/privacy.html`

## 3. Pricing & in-app purchases

App price: **Free**. Then **Features → In-App Purchases / Subscriptions**:

**Subscription group** "TapeScan Pro":

| Reference name | Product ID | Type | Price | Intro offer |
|---|---|---|---|---|
| Pro Monthly | `tapescan.pro.monthly` | Auto-renewable, 1 month | $4.99 | 7-day free trial |
| Pro Annual | `tapescan.pro.annual` | Auto-renewable, 1 year | $24.99 | 7-day free trial |

**In-app purchase** (separate):

| Reference name | Product ID | Type | Price |
|---|---|---|---|
| Pro Lifetime | `tapescan.pro.lifetime` | Non-consumable | $59.99 |

Localized display name suggestion for all three: "TapeScan Pro" + period.
Subscription localization description: "Unlimited exports, USDZ + glTF 3D
models, and cloud sync."

> Product IDs must match exactly — the app fetches these three identifiers
> (`ProductMapping` in `Sources/Services/PurchaseService.swift`).

## 4. App Privacy (nutrition labels)

Data collection: **Yes**, the following — all **linked to the user**, none
used for tracking, purpose **App Functionality**:

- Contact Info → Email Address *(optional accounts)*
- User Content → Other User Content *(measurements & floor plans, for sync)*
- Identifiers → User ID

Everything else: not collected. (Matches `PrivacyInfo.xcprivacy`.)

## 5. Version information

**Promotional text** (170 chars max):
> Measure with your camera, scan rooms into real floor plans, and export to PDF, DXF, CAD & 3D — no ads, no weekly subscription, your data never held hostage.

**Description** (paste as-is):

```
TapeScan turns your iPhone into a tape measure and a floor-plan scanner.

MEASURE ANYTHING
• Point, tap, done — distances, areas, volumes and angles in AR
• LiDAR precision on Pro iPhones (±1–2 cm at room scale), visual mode on the rest
• Honest readings: live tracking guidance instead of silent wrong numbers
• Fractional inches for the job site (12′ 3 5/8″) or metric to the millimeter

SCAN WHOLE ROOMS
• Walk the room once — TapeScan builds the floor plan as you go
• Walls, doors and windows detected automatically (LiDAR iPhones)
• Paint-and-flooring math included: perimeter, floor area, wall area, volume

EXPORT LIKE A PRO
• PDF documents with dimensions and quantities
• DXF for AutoCAD, SVG vectors, PNG images, CSV for spreadsheets
• 3D models in USDZ and glTF
• 3 exports free — then go Pro for unlimited

NEVER LOSE WORK
• Every session autosaves — a crash costs seconds, not the scan
• Optional account backs up and syncs across your iPhones
• No account required, ever. Your measurements stay yours.

TAPESCAN PRO
Unlimited exports, USDZ + glTF 3D models, and cloud sync.
$4.99/month or $24.99/year (both with a 7-day free trial), or a $59.99
one-time lifetime unlock. No ads. No weekly subscriptions. Everything you
create stays viewable forever, subscribed or not.

Measurements are estimates — verify with a physical tape before cutting or
ordering. Room scanning requires a LiDAR-equipped iPhone (Pro models).

Privacy: camera frames never leave your device. Policy:
https://faisalarip.github.io/tapescan-legal/privacy.html
```

**Keywords** (≤100 chars):
`tape measure,ar ruler,room scan,floor plan,lidar,measure,area,blueprint,room planner,cad,dxf`

**Support URL:** `https://faisalarip.github.io/tapescan-legal/support.html`
**Marketing URL:** `https://faisalarip.github.io/tapescan-legal/`

## 6. Screenshots (6.9″ required; 6.5″ optional)

Five-shot plan, captured on device (Measure/Rooms) + Simulator (the rest):

1. Measure HUD mid-measurement with a real distance readout — caption "Measure with your camera".
2. Room scan in progress with the live mini-plan — "Scan rooms in one walk".
3. Finished floor plan with the quantities strip — "Real floor plans, instantly".
4. Export screen with the seven formats — "Export to PDF, DXF, CAD & 3D".
5. Paywall — "Honest pricing. No weekly subscriptions."

Capture: device — Settings→Developer→dark wallpaper, then screenshot;
Simulator — `xcrun simctl io booted screenshot shot.png` after launching with
`-uiPhase main -uiTab rooms` etc.

## 7. App Review information

- Sign-in required? **No** (accounts are optional — leave demo credentials blank).
- Notes for the reviewer (paste):

```
TapeScan is an AR measuring utility.

• No account is required for any feature. The optional sign-in only backs up
  measurements; account deletion is in Settings → Account → Delete Account.
• Room scanning uses Apple RoomPlan and therefore requires a LiDAR iPhone
  (12 Pro or later Pro models). On other devices the feature shows an
  explanatory message — tape measuring still works everywhere.
• AR measuring needs a physical device; the Simulator shows a simulated
  preview by design.
• In-app purchases: TapeScan Pro unlocks unlimited exports. The 3 free
  exports can be exercised without purchase.
```

- Export compliance: uses only standard encryption (HTTPS) → **exempt**
  (`ITSAppUsesNonExemptEncryption=false` is already in Info.plist, so no
  per-build prompt).

## 8. Submit

1. Archive + upload (see `scripts/build-release.sh` tail).
2. Select the build, attach screenshots, submit for review.
3. Respond to reviewer questions via Resolution Center — typical first
   review: 24–48 h.
