# App Store Connect — v1.0 Submission Package

Paste-ready values for the first submission of **3D Lidar Scanner: Room Measure**
(bundle `com.faisalnurarif.tapescan`, Team `5VHRN5SF2P`). Built Universal
(iPhone + iPad) as of commit `0dc4c98`. Replace anything in **{braces}**.

---

## 1. App Information (set once, per app)

| Field | Value |
|---|---|
| **App Name** (≤30) | `3D Lidar Scanner: Room Measure` (exactly 30 chars) |
| **Subtitle** (≤30) | `AR Tape Measure & Floor Plans` (29 chars) |
| **Bundle ID** | `com.faisalnurarif.tapescan` |
| **SKU** | `tapescan-ios-100` *(any unique string; not shown to users)* |
| **Primary Language** | English (U.S.) |
| **Primary Category** | Utilities |
| **Secondary Category** | Productivity |
| **Content Rights** | Does **not** contain, show, or access third-party content |
| **Age Rating** | 4+ (questionnaire: all categories "None" / "No") |

Home-screen label is `TapeScan`; the App Store name differs (allowed). If you
want them to match, that's the parked in-app rebrand — not required to submit.

---

## 2. Pricing & Availability

- **Price:** Free (Tier 0) — monetized via in-app purchases below.
- **Availability:** All countries/regions (or your choice).
- **Distribution:** Public on the App Store.

---

## 3. Version 1.0 — Store Listing

### Promotional Text (≤170, editable anytime)
```
Measure distance, area, volume & angles in AR, then scan rooms into floor plans with LiDAR. Export to PDF, USDZ, DXF & more — and sync across your devices.
```

### Description (≤4000)
```
Turn your iPhone or iPad into a precise AR measuring tool and a LiDAR room scanner. 3D Lidar Scanner: Room Measure uses ARKit to measure the real world — distances, areas, angles, and volumes — and scans entire rooms into clean, shareable floor plans.

MEASURE ANYTHING
• Tap to drop points and measure length, width, height, and diagonals
• Calculate area and volume for rooms, walls, furniture, and boxes
• Measure angles between surfaces
• Precision reticle and point snapping for accurate placement
• Works on any ARKit iPhone or iPad — LiDAR makes it even more precise

SCAN ROOMS INTO FLOOR PLANS (LiDAR)
• Walk a room and watch a floor plan build live
• Captures wall lengths, layout, and total floor area automatically
• Generates a 3D capture (USDZ) of the scanned space

EXPORT IN THE FORMAT YOU NEED
• 3D: USDZ and glTF
• 2D plans: PDF, SVG, and PNG
• CAD & data: DXF and CSV
• Share with clients, contractors, movers, or designers

SAVE & SYNC (optional account)
• Keep every measurement and room in your personal library
• Sign in with Apple, Google, or email to back up and sync across your devices
• Your data is private — never sold and never used for tracking
• Delete your account and all cloud data anytime, right inside the app

FREE TO MEASURE
Measuring and room scanning are free. TapeScan Pro unlocks unlimited exports and cloud sync.

TAPESCAN PRO
• Monthly, Annual, or one-time Lifetime
• 7-day free trial on subscriptions
• Payment is charged to your Apple Account. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple Account settings.

Note: AR measurements are estimates that depend on lighting, surfaces, and device sensors. For critical work, confirm with a physical tape measure.

Questions or feedback? Visit our support page — we read everything.
```

### Keywords (≤100, comma-separated — name/subtitle words omitted on purpose)
```
ruler,distance,area,volume,angle,laser,blueprint,square footage,estimate,contractor,survey,camera
```

### What's New in This Version
```
Welcome to 3D Lidar Scanner: Room Measure — our first release! Measure in AR, scan rooms into floor plans with LiDAR, and export to USDZ, glTF, PDF, SVG, DXF, or CSV. Sign in to sync across your devices, or use it fully as a guest. We'd love your feedback.
```

### URLs
| Field | Value |
|---|---|
| **Support URL** | `https://faisalarip.github.io/tapescan-legal/support.html` |
| **Marketing URL** (optional) | `https://faisalarip.github.io/tapescan-legal/support.html` |
| **Privacy Policy URL** | `https://faisalarip.github.io/tapescan-legal/privacy.html` |

### Other
| Field | Value |
|---|---|
| **Version** | `1.0` |
| **Copyright** | `© 2026 Faisal Nur Arif` *(or your company name)* |
| **Screenshots** | Already prepared (iPhone 6.9"/6.5" + iPad 13"/12.9") |
| **App Preview** | Optional |
| **Build** | Select the build you upload from `main` (≥ `0dc4c98`) |

---

## 4. App Privacy (data collection questionnaire)

Matches the shipped `PrivacyInfo.xcprivacy`. **"Data used to track you": NONE.**
Collected **only when a user chooses to sign in** (guests send nothing):

| Data Type (ASC path) | Linked to user | Used for tracking | Purpose |
|---|---|---|---|
| Contact Info → **Email Address** | Yes | No | App Functionality |
| User Content → **Other User Content** (saved measurements/rooms) | Yes | No | App Functionality |
| Identifiers → **User ID** | Yes | No | App Functionality |

- "Do you collect data from this app?" → **Yes**
- For each of the three: purpose **App Functionality**, **Linked** to identity, **Not** used for tracking.
- No advertising, no analytics SDK, no IDFA, no tracking.

---

## 5. In-App Purchases (create all 3, attach to this version)

**Subscription Group** — Display Name: `TapeScan Pro` (Reference: `TapeScan Pro`).
Add a group localization (en-US) or ASC will block submission.

### 5a. Auto-Renewable — Monthly
| Field | Value |
|---|---|
| Reference Name | `Pro Monthly` |
| Product ID | `tapescan.pro.monthly` |
| Duration | 1 Month |
| Price | USD **4.99** |
| Intro Offer | **Free**, 1 week, new subscribers |
| Display Name | `Pro Monthly` |
| Description | `Unlimited exports (USDZ, glTF, PDF, SVG, DXF, CSV) and cross-device cloud sync.` |

### 5b. Auto-Renewable — Annual
| Field | Value |
|---|---|
| Reference Name | `Pro Annual` |
| Product ID | `tapescan.pro.annual` |
| Duration | 1 Year |
| Price | USD **24.99** |
| Intro Offer | **Free**, 1 week, new subscribers |
| Display Name | `Pro Annual` |
| Description | `Unlimited exports and cloud sync, billed yearly — best value.` |

### 5c. Non-Consumable — Lifetime
| Field | Value |
|---|---|
| Reference Name | `Pro Lifetime` |
| Product ID | `tapescan.pro.lifetime` |
| Price | USD **59.99** |
| Display Name | `Pro Lifetime` |
| Description | `Every Pro feature, forever. One-time purchase.` |

**IAP review screenshot (required for each):** one screenshot of the in-app
paywall (Rooms → any Pro-gated action). The same image works for all three.

---

## 6. App Review Information

| Field | Value |
|---|---|
| Sign-in required to use app? | **No** — fully usable as a guest |
| Demo account | Not required (see notes); optionally provide one |
| Contact | {First} {Last} · {phone} · `faisal.arif@tuntun.co.id` |

### Review Notes (paste)
```
3D Lidar Scanner: Room Measure is an ARKit measuring + LiDAR room-scanning tool.

• No account is required. All AR measuring works on any ARKit device as a guest. LiDAR room scanning requires a LiDAR device (iPhone Pro / iPad Pro); on non-LiDAR devices the app shows an explainer and tape-measuring still works.

• Optional sign-in (Sign in with Apple, Google, or email) only adds cloud backup/sync of saved measurements and rooms. Email sign-in uses a one-time passcode — please use a real inbox to receive the code.

• The Pro purchase asks the user to sign in first because Pro includes cross-device cloud sync, which is tied to an account. All core measuring, scanning, and on-device saving work free without any account or purchase.

• Account deletion: Settings → Account → Delete Account removes the account and all cloud data immediately (Guideline 5.1.1(v)).

• AR measurements are estimates; the app states this in-app.

Thank you for reviewing!
```

---

## 7. Encryption / Export Compliance

`ITSAppUsesNonExemptEncryption = false` is already in Info.plist, so ASC will
**not** prompt. The app uses only standard HTTPS (exempt). No documentation needed.

---

## 8. Pre-submit checklist (must be true before you hit Submit)

- [ ] Three legal pages are **live** (open each in a browser):
      `…/privacy.html`, `…/terms.html`, `…/support.html`. Terms must include the EULA.
- [ ] In Xcode: Product → Archive from `main` (≥ `0dc4c98`), upload to ASC, and **attach** the build to v1.0.
- [ ] All 3 IAPs are created, "Ready to Submit", and **added to the v1.0 version** (first submission reviews IAPs with the app).
- [ ] Subscription group has an en-US localization (display name + optional promo image).
- [ ] App Privacy answers entered (Section 4) and match the binary's privacy manifest.
- [ ] Screenshots uploaded for iPhone + iPad (you have these).
- [ ] Supabase dashboard: Apple + Google providers enabled, email OTP on, redirect `tapescan://` added; Google provider has the iOS client id and (if used) "skip nonce check". Verify a real sign-in on device once.
- [ ] Smoke-test on a physical device: guest measure, LiDAR scan, an export + share, sign-in + sync, purchase (sandbox), restore, and account delete.

_Generated from a pre-submission audit. Verdict at time of writing: 1 blocker (Universal binary) — now fixed; the rest is the ASC data above._
