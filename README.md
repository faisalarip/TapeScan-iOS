# TapeMeasure AR Pro — iOS (SwiftUI)

A native SwiftUI recreation of the **TapeMeasure AR Pro** design: a LiDAR-style AR
measuring app with multi-point distance / area / volume / angle capture, a guided
room scan → floor-plan flow, exports (glTF / SVG / PNG / PDF), and a
RevenueCat-style Pro paywall.

The app is a **white-label template**. Every brand surface, accent color, layout
density and measurement unit is driven from one `@Observable` `AppState`, so the
whole app re-themes live from inside the running Settings screen. The three
backend integrations a buyer needs to ship (AR capture, purchases, sign-in) are
pre-built as **protocol seams** with working in-memory stubs — swap the stub for
the real service and the UI does not change. See **[GO-LIVE.md](GO-LIVE.md)**.

> Builds and runs **entirely in the iOS Simulator** — no device, no ARKit, no
> App Store Connect account required to evaluate the UX end to end.

---

## Requirements

| | |
|---|---|
| Xcode | 16+ (developed/verified on 26.1.1) |
| iOS deployment target | 17.0 |
| Language | Swift 5 mode (Swift 6.2 toolchain) |
| Project generator | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |

---

## Open · Build · Run

```bash
# 1. Generate the Xcode project from project.yml (only needed after adding/removing files)
brew install xcodegen          # if you don't have it
xcodegen generate

# 2. Open in Xcode
open TapeMeasureARPro.xcodeproj
#    → select an iPhone 17 Pro (or any iOS 17+) simulator → ⌘R

# — or build/run from the command line —
xcodebuild \
  -project TapeMeasureARPro.xcodeproj \
  -scheme TapeMeasureARPro \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO build
```

The committed `.xcodeproj` works as-is; you only need XcodeGen if you add or
rename source files.

---

## Screen list

| Flow | Screen | File |
|---|---|---|
| **Auth** | Sign In (Apple/Google seams, email, forgot-password) | `Screens/Auth/SignInView.swift` |
| | Create Account | `Screens/Auth/CreateAccountView.swift` |
| | Verify Code | `Screens/Auth/VerifyCodeView.swift` |
| **Onboarding** | Welcome (AR hero, brand eyebrow) | `Screens/Onboarding/OnbWelcomeView.swift` |
| | Camera Permission CTA | `Screens/Onboarding/OnbPermissionView.swift` |
| | Calibrate | `Screens/Onboarding/OnbCalibrateView.swift` |
| **Measure** (tab) | Host + HUD-style picker | `Screens/Measure/MeasureView.swift` |
| | A · Precision HUD | `Screens/Measure/MeasureAView.swift` |
| | B · Minimal Focus | `Screens/Measure/MeasureBView.swift` |
| | C · Pro Console | `Screens/Measure/MeasureCView.swift` |
| **Rooms** (tab) | Room scan → floor plan | `Screens/Rooms/RoomScanView.swift` |
| | Export (formats + free-export quota) | `Screens/Rooms/ExportView.swift` |
| | Paywall (Pro) | `Screens/Rooms/PaywallView.swift` |
| **History** (tab) | Saved measurements | `Screens/Library/HistoryView.swift` |
| **Settings** (tab) | Reskin / live-tweak panel + Pro upsell | `Screens/Library/SettingsView.swift` |

The Measure tab ships **all three** design directions and makes them switchable
at runtime via a floating "HUD style" picker, so you can compare them without
rebuilding.

---

## Design system & reskin

All theming flows from `Sources/App/AppState.swift` (an `@Observable`
`@MainActor` singleton injected at the root). `Sources/Theme/Theme.swift` is a
value-type **snapshot** of those tokens, rebuilt and re-installed into the
environment whenever `AppState` changes — so mutating a token live re-themes
every screen.

Reskin a buyer's brand by changing these tokens (all editable from the **Settings
tab at runtime**, or as defaults in `AppState`):

| Token | Type | Effect |
|---|---|---|
| `brand` | `String` | Wordmark (Auth), onboarding eyebrow `"{BRAND} AR PRO"`, Settings `"{brand} Pro"` card. Blank → falls back to `"TapeMeasure"`. |
| `accent` | `AccentOption` | The single accent color (5 presets); drives gradients, chips, CTAs, selection states app-wide. |
| `density` | `Density` | `compact` / `regular` / `comfy` — scales every corner radius (`theme.r`) and padding (`theme.p`). |
| `unit` | `MeasureUnit` | `metric` / `imperial` — drives every value via `UnitFormat`. |
| `lidar` | `Bool` | LiDAR vs visual-inertial fallback: precision badges, status chips, fallback banners, mesh/grid density. |

```text
AppState (@Observable)  ──build──▶  Theme (value snapshot)  ──.installTheme()──▶  @Environment(\.theme)
   ▲ Settings controls bind here                                                      every screen reads here
```

To rebrand for a client: set `AppState.brand` / `AppState.accent` defaults, drop
in a new `AppIcon-1024.png`, and update the legal URLs in `LegalLinks`
(`Screens/Rooms/PurchaseService.swift`). No view code changes.

---

## Architecture

- **Presentation** — SwiftUI views, declarative, read `@Environment(\.theme)` +
  `@Environment(AppState.self)`. Reusable atoms live in `Sources/Components`.
- **State** — one `@Observable @MainActor AppState`; `Theme` is the derived,
  `Sendable` snapshot.
- **Service seams** — `ARMeasureService`, `PurchaseService`, and the auth intents
  on `AppState` are protocols with in-memory stubs. They are the three places a
  buyer wires a real backend. See **[GO-LIVE.md](GO-LIVE.md)**.

---

## What's a stub vs. real

| Area | This template | To ship |
|---|---|---|
| AR capture | `SimulatedARMeasureService` + SwiftUI `CameraBackdrop` | `ARMeasureService` → ARKit/RealityKit + LiDAR |
| Purchases | `StubPurchaseService` (returns success, flips `isPro`) | `PurchaseService` → StoreKit 2 / RevenueCat |
| Sign in | `AppState.completeAuth()` | AuthenticationServices (Sign in with Apple) |

These are intentional, documented seams — not bugs. The stubs make the entire UX
loop demonstrable in the Simulator (including a working "purchase → Pro unlocked
→ exports unlimited" demo loop).

---

## Privacy & App Store readiness

- `Sources/Resources/PrivacyInfo.xcprivacy` — privacy manifest (no tracking, no
  collected data for the local-only template; update when a real backend ships).
- `Info.plist` declares `NSCameraUsageDescription` for the AR camera.
- `Assets.xcassets/AppIcon.appiconset` ships a 1024 opaque (RGB, no alpha) icon.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
