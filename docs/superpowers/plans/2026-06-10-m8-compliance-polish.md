# M8 — Compliance, Accessibility & Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Make TapeScan App-Store-compliant and accessible: real hosted legal documents with final in-app URLs, Dynamic Type support across the design system, Reduce Motion support for every looping animation, a truthful privacy manifest, real project docs, and a brand/placeholder audit.

**Architecture:** This milestone touches no service seams — it hardens the existing SwiftUI presentation layer (`Theme` font tokens become Dynamic-Type-aware via a unit-tested point-size → text-style mapping; the four `repeatForever` animations gain `accessibilityReduceMotion` gates with static alternatives) and adds non-code deliverables (a static `legal-site/` published to GitHub Pages, the final `PrivacyInfo.xcprivacy`, a real `README.md`). `LegalLinks` (owned by `Sources/Services/PurchaseService.swift` since M3) is the single source for legal URLs; all paywall/settings/signup links read it.

**Tech Stack:** Swift 5.9 / SwiftUI / iOS 17, UIKit (`UIFontMetrics`) for Dynamic Type scaling, XCTest (`TapeScanTests` target from M1), XcodeGen, plain HTML/CSS for the legal site, GitHub Pages for hosting.

---

**Dependencies & assumptions (read first):**

- Depends on **M3** (purchases) and **M7** (auth & sync) being merged. Per the contracts doc:
  - `PurchaseService.swift` (containing `LegalLinks`) now lives at `Sources/Services/PurchaseService.swift` (moved from `Sources/Screens/Rooms/` by M3). If a grep shows it was not moved, apply the `LegalLinks` edits wherever `enum LegalLinks` is defined.
  - The scheme is **TapeScan**; the unit-test target is **TapeScanTests** with sources under `Tests/TapeScanTests/` (M1). The module to `@testable import` is `TapeScan`.
  - M7 restructured the auth flow (sign-in is a skippable sheet; demo identities like `"4821"` and `alex@studio.co` were removed). Where this plan edits auth-screen code, each task anchors on quoted code and includes a grep-first locator so the edit lands even if M7 moved it.
- Line numbers cited below are from the pre-M8 audit of the named files. M3/M4/M7 edits may shift them — always match on the quoted code, not the line number.
- Build verification command (used throughout):
  `xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- Unit-test command (used throughout):
  `xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test`

---

### Task 1: Dynamic Type mapping table — `Theme.textStyle(for:)` (TDD)

The design system uses fixed point sizes (`Theme.sans(15)`, `Theme.mono(10.5)`, … — 104 call sites). To scale them with Dynamic Type we first need a pure, unit-tested mapping from a design point size to the `Font.TextStyle` whose scaling curve it should follow.

Documented mapping table (this is the contract for the whole milestone):

| Design points | Text style |
|---|---|
| < 13 | `.caption2` |
| 13 – 14.x | `.footnote` |
| 15 – 15.x | `.subheadline` |
| 16 – 17.x | `.body` |
| 18 – 19.x | `.headline` |
| 20 – 23.x | `.title3` |
| 24 – 27.x | `.title2` |
| ≥ 28 | `.largeTitle` |

**Files:**
- Create: `Tests/TapeScanTests/ThemeFontMappingTests.swift`
- Modify: `Sources/Theme/Theme.swift` (add to the `// MARK: - Fonts` section, currently lines 108–117)

- [ ] **Step 1: Write the failing mapping tests.** Create `Tests/TapeScanTests/ThemeFontMappingTests.swift` with exactly:

```swift
// ThemeFontMappingTests.swift — Theme.textStyle(for:) Dynamic Type mapping table.
//
// The table is the M8 contract: every Theme.sans/mono point size scales along
// the curve of the text style returned here.

import XCTest
import SwiftUI
@testable import TapeScan

final class ThemeFontMappingTests: XCTestCase {

    func testSizesBelow13MapToCaption2() {
        XCTAssertEqual(Theme.textStyle(for: 9.5), .caption2)
        XCTAssertEqual(Theme.textStyle(for: 10.5), .caption2)
        XCTAssertEqual(Theme.textStyle(for: 11.5), .caption2)
        XCTAssertEqual(Theme.textStyle(for: 12), .caption2)
        XCTAssertEqual(Theme.textStyle(for: 12.5), .caption2)
    }

    func testSizes13To14MapToFootnote() {
        XCTAssertEqual(Theme.textStyle(for: 13), .footnote)
        XCTAssertEqual(Theme.textStyle(for: 13.5), .footnote)
        XCTAssertEqual(Theme.textStyle(for: 14.5), .footnote)
    }

    func testSize15BandMapsToSubheadline() {
        XCTAssertEqual(Theme.textStyle(for: 15), .subheadline)
        XCTAssertEqual(Theme.textStyle(for: 15.5), .subheadline)
    }

    func testSizes16To17MapToBody() {
        XCTAssertEqual(Theme.textStyle(for: 16), .body)
        XCTAssertEqual(Theme.textStyle(for: 17), .body)
        XCTAssertEqual(Theme.textStyle(for: 17.9), .body)
    }

    func testSizes18To19MapToHeadline() {
        XCTAssertEqual(Theme.textStyle(for: 18), .headline)
        XCTAssertEqual(Theme.textStyle(for: 19), .headline)
    }

    func testSizes20To23MapToTitle3() {
        XCTAssertEqual(Theme.textStyle(for: 20), .title3)
        XCTAssertEqual(Theme.textStyle(for: 23.5), .title3)
    }

    func testSizes24To27MapToTitle2() {
        XCTAssertEqual(Theme.textStyle(for: 24), .title2)
        XCTAssertEqual(Theme.textStyle(for: 25), .title2)
        XCTAssertEqual(Theme.textStyle(for: 27.5), .title2)
    }

    func testSizes28AndUpMapToLargeTitle() {
        XCTAssertEqual(Theme.textStyle(for: 28), .largeTitle)
        XCTAssertEqual(Theme.textStyle(for: 30), .largeTitle)
        XCTAssertEqual(Theme.textStyle(for: 46), .largeTitle)
    }
}
```

- [ ] **Step 2: Regenerate the project and run the test (expect RED).**

```bash
cd /Users/faisalnurarif/Documents/PersonalApps/TapeMeasureARPro-iOS
xcodegen generate
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO \
  test -only-testing:TapeScanTests/ThemeFontMappingTests
```

Expected failure: the test target fails to compile with `error: type 'Theme' has no member 'textStyle'` and the run ends with `** TEST FAILED **`. A compile failure of the test target is the red state here.

- [ ] **Step 3: Implement `Theme.textStyle(for:)`.** In `Sources/Theme/Theme.swift`, inside the `// MARK: - Fonts` section (directly above `public static func sans`), add:

```swift
    // Dynamic Type mapping table (M8). Design point sizes are preserved at the
    // default text size and scale along the curve of the mapped text style:
    //
    //   < 13      → .caption2
    //   13 – 14.x → .footnote
    //   15 – 15.x → .subheadline
    //   16 – 17.x → .body
    //   18 – 19.x → .headline
    //   20 – 23.x → .title3
    //   24 – 27.x → .title2
    //   ≥ 28      → .largeTitle

    /// Maps a design point size to the Dynamic Type text style it scales with.
    public static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<13: return .caption2
        case ..<15: return .footnote
        case ..<16: return .subheadline
        case ..<18: return .body
        case ..<20: return .headline
        case ..<24: return .title3
        case ..<28: return .title2
        default:    return .largeTitle
        }
    }
```

- [ ] **Step 4: Run the tests (expect GREEN).**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO \
  test -only-testing:TapeScanTests/ThemeFontMappingTests
```

Expected output ends with `** TEST SUCCEEDED **` and all 8 `ThemeFontMappingTests` pass.

- [ ] **Step 5: Commit.**

```bash
git add Tests/TapeScanTests/ThemeFontMappingTests.swift Sources/Theme/Theme.swift TapeMeasureARPro.xcodeproj
git commit -m "feat(theme): map design point sizes to Dynamic Type text styles" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Scale `Theme.sans`/`Theme.mono` with Dynamic Type (TDD)

`Font.system(size:)` is fixed-size in SwiftUI. We scale the requested size through `UIFontMetrics` using the mapped text style's curve (the `relativeTo:` semantics from the spec), so every one of the 104 call sites becomes Dynamic-Type-aware without changing any call site. At the default content size (`.large`) the scaling is the identity, so the shipped design is pixel-identical for default settings. `RootView` also gets an `.id(dynamicTypeSize)` so a runtime text-size change (Control Center slider) rebuilds the tree and recomputes the fonts.

**Files:**
- Modify: `Tests/TapeScanTests/ThemeFontMappingTests.swift` (add 2 tests)
- Modify: `Sources/Theme/Theme.swift` (imports at line 16; `sans`/`mono` currently lines 110–117)
- Modify: `Sources/App/RootView.swift` (env property after the `@Environment(AppState.self)` line, currently line 12; modifier before `.installTheme(Theme(appState))`, currently line 34)

- [ ] **Step 1: Add failing scaling tests.** Append these two test methods inside `final class ThemeFontMappingTests` in `Tests/TapeScanTests/ThemeFontMappingTests.swift`:

```swift
    func testScaledSizeIsIdentityAtDefaultContentSize() {
        // .large is the Dynamic Type baseline: UIFontMetrics scaling is the
        // identity there, so the shipped design is unchanged at default settings.
        XCTAssertEqual(Theme.scaledSize(15, for: .large), 15, accuracy: 0.01)
        XCTAssertEqual(Theme.scaledSize(10.5, for: .large), 10.5, accuracy: 0.01)
        XCTAssertEqual(Theme.scaledSize(46, for: .large), 46, accuracy: 0.01)
    }

    func testScaledSizeGrowsAtAccessibilityXL() {
        XCTAssertGreaterThan(Theme.scaledSize(15, for: .accessibilityExtraLarge), 15)
        XCTAssertGreaterThan(Theme.scaledSize(10.5, for: .accessibilityExtraLarge), 10.5)
        XCTAssertGreaterThan(Theme.scaledSize(28, for: .accessibilityExtraLarge), 28)
    }
```

- [ ] **Step 2: Run (expect RED — compile error).**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO \
  test -only-testing:TapeScanTests/ThemeFontMappingTests
```

Expected failure: `error: type 'Theme' has no member 'scaledSize'`, `** TEST FAILED **`.

- [ ] **Step 3: Implement scaling in `Theme.swift`.** First, change the import block (currently line 16, `import SwiftUI`) to:

```swift
import SwiftUI
import UIKit
```

Then replace the existing `sans`/`mono` implementations:

```swift
    /// SF Pro (system default sans).
    public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    /// SF Mono (`.monospaced`) for telemetry / numbers.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
```

with:

```swift
    /// UIKit twin of ``textStyle(for:)`` — selects the UIFontMetrics curve.
    private static func uiTextStyle(for size: CGFloat) -> UIFont.TextStyle {
        switch textStyle(for: size) {
        case .caption2:    return .caption2
        case .footnote:    return .footnote
        case .subheadline: return .subheadline
        case .body:        return .body
        case .headline:    return .headline
        case .title3:      return .title3
        case .title2:      return .title2
        case .largeTitle:  return .largeTitle
        default:           return .body
        }
    }

    /// Scales `size` for an explicit content-size category along the mapped
    /// text style's curve. Identity at `.large` (the baseline). Pure given the
    /// category — this is the unit-testable seam.
    public static func scaledSize(_ size: CGFloat, for category: UIContentSizeCategory) -> CGFloat {
        UIFontMetrics(forTextStyle: uiTextStyle(for: size))
            .scaledValue(for: size,
                         compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
    }

    /// The app-wide preferred category. Fonts are built during main-thread view
    /// rendering; any off-main caller gets the `.large` baseline (no scaling).
    private static func currentCategory() -> UIContentSizeCategory {
        guard Thread.isMainThread else { return .large }
        return MainActor.assumeIsolated { UIApplication.shared.preferredContentSizeCategory }
    }

    /// SF Pro (system default sans), scaled for the user's Dynamic Type setting.
    public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaledSize(size, for: currentCategory()), weight: weight, design: .default)
    }
    /// SF Mono (`.monospaced`) for telemetry / numbers, scaled for Dynamic Type.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaledSize(size, for: currentCategory()), weight: weight, design: .monospaced)
    }
```

(`sans`/`mono` stay nonisolated on purpose — view helper methods that call them are not MainActor-isolated in Swift 5 mode. `MainActor.assumeIsolated` is safe behind the `Thread.isMainThread` guard.)

- [ ] **Step 4: Run the tests (expect GREEN).** Same command as Step 2; expected `** TEST SUCCEEDED **`, 10 tests passing.

- [ ] **Step 5: Rebuild on runtime type-size changes.** In `Sources/App/RootView.swift`, add an environment property directly below the `@Environment(AppState.self) private var appState` line:

```swift
    @Environment(\.dynamicTypeSize) private var typeSize
```

and insert `.id(typeSize)` immediately **before** the existing `.installTheme(Theme(appState))` modifier:

```swift
        // Rebuild the tree when Dynamic Type changes at runtime so the
        // UIFontMetrics-scaled fonts in Theme.sans/mono are recomputed.
        // Identity only changes on a text-size change, so the transient
        // state reset is acceptable.
        .id(typeSize)
        // Derive + install the live theme; re-runs whenever any tweak changes.
        .installTheme(Theme(appState))
```

- [ ] **Step 6: Build verification.**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit.**

```bash
git add Sources/Theme/Theme.swift Sources/App/RootView.swift Tests/TapeScanTests/ThemeFontMappingTests.swift
git commit -m "feat(theme): scale Theme.sans/mono with Dynamic Type via UIFontMetrics" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Accessibility-XL clipping spot fixes (paywall plan cards, Measure HUD chips, Settings rows)

With Task 2 live, the fixed-height pills and tight rows clip at accessibility sizes. Relax them with `minHeight`, `lineLimit`, and `minimumScaleFactor` — no visual change at default size.

**Files:**
- Modify: `Sources/Components/Chip.swift` (`Chip.body` currently lines 62–81; `FallbackBanner.body` lines 90–104)
- Modify: `Sources/Screens/Rooms/PaywallView.swift` (`planRow(_:)` — `Text(plan.id)` at line 205, `Text(plan.subtitle)` at line 218, `Text(plan.price)` at line 235; M3 may have shifted these — anchor on the quoted code)
- Modify: `Sources/Screens/Measure/MeasureAView.swift` (`telemetryStrip` font/tracking modifiers, currently lines 121–122; M4 may have shifted them)
- Modify: `Sources/Screens/Library/GroupedList.swift` (`DRow` subtitle at lines 103–107, detail at lines 112–116)

- [ ] **Step 1: Relax `Chip`.** In `Sources/Components/Chip.swift`, in `Chip.body`, add `.lineLimit(1)` and `.minimumScaleFactor(0.75)` after `.tracking(0.2)`, and change `.frame(height: height)` to `.frame(minHeight: height)`:

```swift
    public var body: some View {
        HStack(spacing: 6) {
            content
        }
        .font(mono ? Theme.mono(fontSize, weight: .semibold)
                   : Theme.sans(fontSize, weight: .semibold))
        .tracking(0.2)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .foregroundStyle(active ? Color.white : Color.white.opacity(0.82))
        .padding(.horizontal, 11)
        .frame(minHeight: height)
        .background(
            Capsule().fill(active ? accent.withA(0.9) : Theme.glass)
        )
        .overlay(
            Capsule().strokeBorder(
                active ? accent.withA(0.4) : Color.white.opacity(0.13),
                lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
    }
```

- [ ] **Step 2: Relax `FallbackBanner`.** In the same file, replace `FallbackBanner.body` with:

```swift
    public var body: some View {
        HStack(spacing: 7) {
            StatusDot(color: amber, blink: true)
            Text("Visual-inertial tracking · LiDAR not detected")
        }
        .font(Theme.sans(11.5, weight: .semibold))
        .tracking(0.1)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .foregroundStyle(Color.white.opacity(0.9))
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .frame(minHeight: 26)
        .background(Capsule().fill(amber.withA(0.14)))
        .overlay(Capsule().strokeBorder(amber.withA(0.45), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        .fixedSize(horizontal: false, vertical: true)
    }
```

(Changes vs. current: `lineLimit(2)`, `minimumScaleFactor(0.8)`, `.padding(.vertical, 5)`, `frame(height: 26)` → `frame(minHeight: 26)`, `.fixedSize()` → `.fixedSize(horizontal: false, vertical: true)` so long text wraps instead of overflowing the screen.)

- [ ] **Step 3: Relax the paywall plan rows.** In `Sources/Screens/Rooms/PaywallView.swift`, inside `planRow(_:)`:
  - On `Text(plan.id)` (the plan title, font `Theme.sans(15.5, weight: .semibold)`), add after `.foregroundStyle(Theme.ink)`:
    ```swift
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
    ```
  - On `Text(plan.subtitle)` (font `Theme.sans(12)`), add after `.foregroundStyle(Theme.ink3)`:
    ```swift
                        .lineLimit(2)
    ```
  - On `Text(plan.price)` (font `Theme.sans(16, weight: .bold)`), add after `.foregroundStyle(Theme.ink)`:
    ```swift
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
    ```

- [ ] **Step 4: Relax the Measure HUD telemetry strip.** In `Sources/Screens/Measure/MeasureAView.swift`, locate the `telemetryStrip` view (the `HStack(spacing: 14)` whose modifiers include `.font(Theme.mono(10.5))` and `.tracking(0.3)` — currently lines 121–122; M4's rewrite keeps the strip's visual style). Add directly after `.tracking(0.3)`:

```swift
        .lineLimit(1)
        .minimumScaleFactor(0.6)
```

- [ ] **Step 5: Relax Settings rows.** In `Sources/Screens/Library/GroupedList.swift`, inside `DRow.body`:
  - Subtitle text: change `.lineLimit(1)` to `.lineLimit(2)` (keep `.truncationMode(.tail)`).
  - Detail text (`Text(detail)` with `Theme.mono(14, weight: .semibold)`): add after `.foregroundStyle(Theme.ink2)`:
    ```swift
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
    ```

- [ ] **Step 6: Build verification.**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Simulator spot-check at accessibility XL.** Boot an iPhone 17 Pro simulator, set the content size, launch, and eyeball the three scoped surfaces:

```bash
xcrun simctl boot "iPhone 17 Pro" || true
open -a Simulator
xcrun simctl ui booted content_size accessibility-extra-large
```

Then run the app from Xcode (scheme TapeScan) or `xcodebuild ... build` + `xcrun simctl install booted <path-to-app>` + `xcrun simctl launch booted co.tuntun.tapescan`. Check: (a) Paywall — plan titles/prices fit on one line, subtitles wrap to 2 lines, no vertical clipping of the cards; (b) Measure tab — mode/status chips grow vertically instead of clipping, telemetry strip stays on one line (scaled down); (c) Settings — row subtitles wrap to 2 lines, detail values shrink instead of truncating. Reset afterwards with `xcrun simctl ui booted content_size large`.

- [ ] **Step 8: Commit.**

```bash
git add Sources/Components/Chip.swift Sources/Screens/Rooms/PaywallView.swift Sources/Screens/Measure/MeasureAView.swift Sources/Screens/Library/GroupedList.swift
git commit -m "fix(a11y): relax layouts that clip at accessibility text sizes" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Reduce Motion — gate the 4 `repeatForever` animations

The four loops (verified by `grep -rn "repeatForever" Sources --include="*.swift"`): `Reticle` pulse (`Sources/Components/Reticle.swift:66`), `StatusDot` blink (`Sources/Components/Chip.swift:25`), `CameraBackdrop` scan sweep (`Sources/Components/CameraBackdrop.swift:108`; the film grain in the same file is already static — no gate needed, document it), and `BlinkingCaret` in `Sources/Screens/Auth/VerifyCodeView.swift:221`. Each gets `@Environment(\.accessibilityReduceMotion)` and a static alternative.

**Files:**
- Modify: `Sources/Components/Reticle.swift`
- Modify: `Sources/Components/Chip.swift`
- Modify: `Sources/Components/CameraBackdrop.swift`
- Modify: `Sources/Screens/Auth/VerifyCodeView.swift` (the private `BlinkingCaret` struct — M7's rewrite keeps it; locate via `grep -n "BlinkingCaret" Sources/Screens/Auth/VerifyCodeView.swift`)

- [ ] **Step 1: Gate the Reticle pulse.** In `Sources/Components/Reticle.swift`, add below `@State private var animate = false`:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Replace the pulse ring block (the `if pulse { Circle()... }` at the top of the `ZStack`) with:

```swift
                if pulse {
                    // Reduce Motion: park the pulse ring at a fixed mid-state
                    // instead of animating scale/opacity.
                    Circle()
                        .stroke(accent, lineWidth: 1.5)
                        .frame(width: 64, height: 64)
                        .scaleEffect(reduceMotion ? 1.09 : (animate ? 1.18 : 1.0))
                        .opacity(reduceMotion ? 0.35 : (animate ? 0.15 : 0.55))
                }
```

Replace the `.onAppear` block with:

```swift
        .onAppear {
            guard pulse, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
```

- [ ] **Step 2: Gate the StatusDot blink.** In `Sources/Components/Chip.swift`, in `StatusDot`, add below `@State private var on = true`:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

and replace its `.onAppear` block with:

```swift
            .onAppear {
                // Reduce Motion: a steady dot still communicates the status.
                guard blink, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    on = false
                }
            }
```

- [ ] **Step 3: Gate the CameraBackdrop scan sweep.** In `Sources/Components/CameraBackdrop.swift`, add below `@State private var scanPhase: CGFloat = 0`:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Replace the scan-sweep block (`if scan { LinearGradient... }`) with:

```swift
                // scan sweep — under Reduce Motion it parks as a static band.
                // (FilmGrain above is already static; no gating needed there.)
                if scan {
                    LinearGradient(
                        colors: [.clear, accent.withA(0.18)],
                        startPoint: .top, endPoint: .bottom)
                    .frame(height: h * 0.4)
                    .position(x: w / 2, y: reduceMotion ? h * 0.62 : h * scanPhase)
                    .opacity(reduceMotion ? 0.35 : (scanPhase < 0.2 || scanPhase > 1.0 ? 0 : 0.5))
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: false)) {
                            scanPhase = 1.3
                        }
                    }
                }
```

- [ ] **Step 4: Gate the OTP caret blink.** In `Sources/Screens/Auth/VerifyCodeView.swift`, replace the private `BlinkingCaret` struct with:

```swift
/// 1.5pt accent caret. Hard-blinks on a 1s cycle (source `tmBlink 1s steps(1)
/// infinite`); under Reduce Motion it renders as a solid, non-animating caret.
private struct BlinkingCaret: View {
    let color: Color
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 1.5, height: height)
            .opacity(visible ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
```

- [ ] **Step 5: Confirm no loop was missed.**

```bash
grep -rn "repeatForever" /Users/faisalnurarif/Documents/PersonalApps/TapeMeasureARPro-iOS/Sources --include="*.swift"
```

Expected: exactly 4 matches, each inside an `.onAppear` that starts with a `guard … !reduceMotion else { return }` (verify by reading the 3 surrounding lines of each match).

- [ ] **Step 6: Build verification.**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Simulator spot-check.** Enable Reduce Motion on the booted simulator, relaunch the app, and verify the reticle ring, status dots, scan sweep, and OTP caret are static:

```bash
xcrun simctl spawn booted defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
xcrun simctl terminate booted co.tuntun.tapescan || true
xcrun simctl launch booted co.tuntun.tapescan
```

(If the defaults write does not take effect, set it manually: Simulator → Settings app → Accessibility → Motion → Reduce Motion ON.) Reset afterwards with the same command and `-bool false`.

- [ ] **Step 8: Commit.**

```bash
git add Sources/Components/Reticle.swift Sources/Components/Chip.swift Sources/Components/CameraBackdrop.swift Sources/Screens/Auth/VerifyCodeView.swift
git commit -m "feat(a11y): honor Reduce Motion for all repeat-forever animations" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Legal static site (`legal-site/`)

Complete, real legal documents for TapeScan, ready to publish on GitHub Pages. Facts baked into the documents: AR measurement app; optional Supabase-backed accounts storing email + measurements/rooms; StoreKit purchases handled by Apple; no tracking, no ads, no analytics; camera frames processed on-device only; data deletion via in-app account deletion; contact `faisal.arif@tuntun.co.id`. Documentation/config task — no unit tests; verification is HTML lint-by-open + link check.

**Files:**
- Create: `legal-site/index.html`
- Create: `legal-site/privacy.html`
- Create: `legal-site/terms.html`
- Create: `legal-site/support.html`
- Create: `legal-site/README.md`

- [ ] **Step 1: Create `legal-site/index.html`** with exactly:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>TapeScan — Legal &amp; Support</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
         max-width: 720px; margin: 0 auto; padding: 48px 24px; color: #1c1c1e; line-height: 1.6; }
  h1 { font-size: 28px; letter-spacing: -0.5px; }
  h2 { font-size: 20px; margin-top: 32px; }
  a { color: #0a66c2; }
  .muted { color: #6e6e73; font-size: 14px; }
  ul { padding-left: 20px; }
  footer { margin-top: 48px; border-top: 1px solid #e5e5ea; padding-top: 16px; }
</style>
</head>
<body>
<h1>TapeScan</h1>
<p>TapeScan is an AR tape measure and floor-plan app for iPhone. Measure distances,
areas, volumes and angles with your camera, scan rooms into editable floor plans,
and export them as PDF, PNG, SVG, USDZ or glTF.</p>

<h2>Legal &amp; support</h2>
<ul>
  <li><a href="privacy.html">Privacy Policy</a></li>
  <li><a href="terms.html">Terms of Use</a></li>
  <li><a href="support.html">Support &amp; FAQ</a></li>
</ul>

<footer class="muted">
  Contact: <a href="mailto:faisal.arif@tuntun.co.id">faisal.arif@tuntun.co.id</a>
</footer>
</body>
</html>
```

- [ ] **Step 2: Create `legal-site/privacy.html`** with exactly:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>TapeScan — Privacy Policy</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
         max-width: 720px; margin: 0 auto; padding: 48px 24px; color: #1c1c1e; line-height: 1.6; }
  h1 { font-size: 28px; letter-spacing: -0.5px; }
  h2 { font-size: 20px; margin-top: 32px; }
  a { color: #0a66c2; }
  .muted { color: #6e6e73; font-size: 14px; }
  ul { padding-left: 20px; }
  footer { margin-top: 48px; border-top: 1px solid #e5e5ea; padding-top: 16px; }
</style>
</head>
<body>
<h1>TapeScan Privacy Policy</h1>
<p class="muted">Effective date: June 10, 2026</p>

<p>This policy describes what data the TapeScan iOS app ("TapeScan", "we", "us")
collects, why, and what control you have over it. The short version: TapeScan
works fully without an account, never tracks you, shows no ads, and the camera
frames used for measuring never leave your device.</p>

<h2>1. Data processed on your device only</h2>
<ul>
  <li><strong>Camera frames.</strong> TapeScan uses your camera and (when available)
      the LiDAR sensor to detect surfaces and place measurement points. All frame
      processing happens on your device. Frames are never stored, uploaded, or
      shared.</li>
  <li><strong>App settings.</strong> Preferences such as measurement units, accent
      color and layout density are stored locally on your device.</li>
</ul>

<h2>2. Data we collect — only if you create an account</h2>
<p>Accounts are optional. Every feature of TapeScan works without one. If you sign
in (Sign in with Apple, Google, or an email one-time code) to back up and sync
your data, we collect:</p>
<ul>
  <li><strong>Email address</strong> — to identify your account and send sign-in
      codes.</li>
  <li><strong>User ID</strong> — a random identifier created for your account.</li>
  <li><strong>Your measurements and room scans</strong> (names, geometry, computed
      values, floor plans) — so they sync across reinstalls and devices.</li>
</ul>
<p>This data is linked to your account, used solely to provide app functionality
(backup and sync), and is never used for tracking or advertising and never sold
or shared with third parties for their own purposes.</p>

<h2>3. Purchases</h2>
<p>Pro subscriptions and the lifetime unlock are processed entirely by Apple
through the App Store. We never see your payment details. We process only your
purchase entitlement (whether your Apple ID owns TapeScan Pro) to unlock Pro
features, and Apple may share aggregate purchase records with us through App
Store Connect.</p>

<h2>4. Where your data is stored</h2>
<p>Account data (email, user ID, measurements, rooms) is stored with our hosting
provider, Supabase, in an access-controlled database. Data is encrypted in
transit (TLS), and database row-level security ensures only your authenticated
account can read or write your rows.</p>

<h2>5. What we do not do</h2>
<ul>
  <li>No advertising and no ad networks.</li>
  <li>No tracking across apps or websites; no device fingerprinting; no IDFA use.</li>
  <li>No third-party analytics SDKs.</li>
  <li>No collection of location, contacts, photos, or any data not listed above.</li>
</ul>

<h2>6. Data retention and deletion</h2>
<p>Your synced data is kept while your account exists. You can delete your
account at any time inside the app: <strong>Settings → Delete account</strong>.
This permanently deletes your account and all server-side data (email, user ID,
measurements, rooms). Data stored locally on your device stays on your device
unless you also choose to erase it; deleting the app removes all local data.</p>

<h2>7. Your rights</h2>
<p>You may access your synced data in the app at any time, export your rooms,
and delete everything via in-app account deletion. For any other privacy
request (including a copy or correction of your data), email us — we respond
within 30 days.</p>

<h2>8. Children</h2>
<p>TapeScan is not directed at children under 13 and we do not knowingly collect
personal data from them. If you believe a child has created an account, contact
us and we will delete it.</p>

<h2>9. Changes to this policy</h2>
<p>If we change this policy, we will update this page and the effective date
above. Material changes will be highlighted in the app's release notes.</p>

<h2>10. Contact</h2>
<p>Privacy questions and requests:
<a href="mailto:faisal.arif@tuntun.co.id">faisal.arif@tuntun.co.id</a></p>

<footer class="muted">
  <a href="index.html">TapeScan home</a> · <a href="terms.html">Terms of Use</a> ·
  <a href="support.html">Support</a>
</footer>
</body>
</html>
```

- [ ] **Step 3: Create `legal-site/terms.html`** with exactly:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>TapeScan — Terms of Use</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
         max-width: 720px; margin: 0 auto; padding: 48px 24px; color: #1c1c1e; line-height: 1.6; }
  h1 { font-size: 28px; letter-spacing: -0.5px; }
  h2 { font-size: 20px; margin-top: 32px; }
  a { color: #0a66c2; }
  .muted { color: #6e6e73; font-size: 14px; }
  ul { padding-left: 20px; }
  footer { margin-top: 48px; border-top: 1px solid #e5e5ea; padding-top: 16px; }
</style>
</head>
<body>
<h1>TapeScan Terms of Use</h1>
<p class="muted">Effective date: June 10, 2026</p>

<h2>1. Agreement</h2>
<p>By downloading or using the TapeScan iOS app ("TapeScan", "the app", "we",
"us"), you agree to these terms. If you do not agree, do not use the app. Your
use of the app is also subject to Apple's standard
<a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Licensed
Application End User License Agreement</a>; where these terms are more
restrictive, these terms apply.</p>

<h2>2. The service</h2>
<p>TapeScan provides augmented-reality measuring (distance, area, volume, angle),
room scanning into floor plans, and export of those plans (PDF, PNG, SVG, USDZ,
glTF). Some features require specific hardware: room scanning requires a
LiDAR-equipped iPhone.</p>

<h2>3. Measurement accuracy — important</h2>
<p><strong>All measurements produced by TapeScan are estimates.</strong> Accuracy
depends on lighting, surface texture, device hardware and tracking quality.
TapeScan must not be relied upon as the sole basis for construction,
engineering, safety-critical, legal, or commercial decisions. Always verify
critical dimensions with a physical measuring tool. We accept no liability for
decisions made on the basis of in-app measurements.</p>

<h2>4. Accounts</h2>
<p>An account is optional and only needed for backup and sync. You are
responsible for the email address you register and for activity on your
account. You may delete your account at any time in the app
(Settings → Delete account).</p>

<h2>5. Purchases and subscriptions</h2>
<ul>
  <li>TapeScan Pro is available as a monthly subscription, an annual subscription
      (each with a 7-day free trial), or a one-time lifetime purchase.</li>
  <li>Payment is charged to your Apple ID at confirmation of purchase.
      Subscriptions auto-renew unless cancelled at least 24 hours before the end
      of the current period; manage or cancel them in your Apple ID settings.</li>
  <li>Unused trial time is forfeited when you purchase.</li>
  <li>Refunds are handled by Apple under App Store policies.</li>
  <li>Prices are shown in the app in your local currency before purchase.</li>
</ul>

<h2>6. Acceptable use</h2>
<p>You may not reverse engineer, resell, or misuse the app; use it to violate
others' privacy or property rights; or attempt to disrupt the sync service.</p>

<h2>7. Your content</h2>
<p>Measurements, rooms and floor plans you create are yours. If you enable sync,
you grant us the limited right to store and transmit that content solely to
provide backup and sync. We claim no other rights over it.</p>

<h2>8. Intellectual property</h2>
<p>The app, its design and its software are owned by us and protected by law.
These terms grant you a personal, non-transferable, non-exclusive licence to use
the app on Apple devices you own or control.</p>

<h2>9. Disclaimer of warranties</h2>
<p>The app is provided "as is" and "as available", without warranties of any
kind, express or implied, including fitness for a particular purpose and
accuracy (see section 3).</p>

<h2>10. Limitation of liability</h2>
<p>To the maximum extent permitted by law, we are not liable for indirect,
incidental, special or consequential damages, or loss of data or profits,
arising from your use of the app. Our total liability is limited to the amount
you paid for the app in the 12 months before the claim.</p>

<h2>11. Termination</h2>
<p>You may stop using the app at any time. We may suspend or terminate access to
the sync service for breach of these terms; your local app functionality is not
affected by such termination.</p>

<h2>12. Governing law</h2>
<p>These terms are governed by the laws of the Republic of Indonesia, without
regard to conflict-of-law rules. Mandatory consumer-protection law of your
country of residence remains unaffected.</p>

<h2>13. Changes</h2>
<p>We may update these terms; the effective date above will change and material
updates will be noted in the app's release notes. Continued use after an update
constitutes acceptance.</p>

<h2>14. Contact</h2>
<p><a href="mailto:faisal.arif@tuntun.co.id">faisal.arif@tuntun.co.id</a></p>

<footer class="muted">
  <a href="index.html">TapeScan home</a> · <a href="privacy.html">Privacy Policy</a> ·
  <a href="support.html">Support</a>
</footer>
</body>
</html>
```

- [ ] **Step 4: Create `legal-site/support.html`** with exactly:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>TapeScan — Support</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
         max-width: 720px; margin: 0 auto; padding: 48px 24px; color: #1c1c1e; line-height: 1.6; }
  h1 { font-size: 28px; letter-spacing: -0.5px; }
  h2 { font-size: 20px; margin-top: 32px; }
  a { color: #0a66c2; }
  .muted { color: #6e6e73; font-size: 14px; }
  ul { padding-left: 20px; }
  footer { margin-top: 48px; border-top: 1px solid #e5e5ea; padding-top: 16px; }
</style>
</head>
<body>
<h1>TapeScan Support</h1>
<p>Questions, bug reports, feature requests:
<a href="mailto:faisal.arif@tuntun.co.id">faisal.arif@tuntun.co.id</a>.
We aim to reply within 2 business days.</p>

<h2>Frequently asked questions</h2>

<h2>Why can't I scan a room?</h2>
<p>Room scanning uses Apple RoomPlan, which requires a LiDAR-equipped iPhone
(iPhone 12 Pro or later Pro/Pro&nbsp;Max models). Measuring works on all
supported iPhones — without LiDAR the app falls back to visual-inertial plane
detection with slightly lower precision.</p>

<h2>How accurate are measurements?</h2>
<p>On LiDAR devices, short-range measurements are typically within about ±1 cm
in good lighting; without LiDAR expect roughly ±2 cm. Accuracy degrades on
reflective, dark or featureless surfaces. Always verify critical dimensions
with a physical tape measure.</p>

<h2>How do I restore my Pro purchase?</h2>
<p>Settings → Restore Purchases, signed in to the same Apple ID that bought
Pro. Subscriptions can be managed or cancelled via Settings → Manage
Subscription (or your Apple ID subscription settings).</p>

<h2>Which export formats are supported?</h2>
<p>PDF and PNG (dimensioned plan), SVG (vector plan), USDZ and glTF (3D model).
Free accounts include 3 exports; Pro removes the limit.</p>

<h2>Do I need an account?</h2>
<p>No. Accounts are optional and only enable backup and sync of your
measurements and rooms across devices and reinstalls.</p>

<h2>How do I delete my account and data?</h2>
<p>Settings → Delete account. This permanently removes your account and all
synced data from our servers. See the
<a href="privacy.html">Privacy Policy</a> for details.</p>

<h2>The camera view is black / permission denied</h2>
<p>iOS Settings → Privacy &amp; Security → Camera → enable TapeScan, then
relaunch the app.</p>

<footer class="muted">
  <a href="index.html">TapeScan home</a> · <a href="privacy.html">Privacy Policy</a> ·
  <a href="terms.html">Terms of Use</a>
</footer>
</body>
</html>
```

- [ ] **Step 5: Create `legal-site/README.md`** with exactly:

```markdown
# TapeScan legal site — publishing to GitHub Pages

This folder is a complete static site (no build step): `index.html`,
`privacy.html`, `terms.html`, `support.html`.

## URL pattern

Once published, the pages live at:

    https://<github-username>.github.io/tapescan-legal/index.html
    https://<github-username>.github.io/tapescan-legal/privacy.html
    https://<github-username>.github.io/tapescan-legal/terms.html
    https://<github-username>.github.io/tapescan-legal/support.html

`<github-username>` is **OWNER-INPUT**: the GitHub account that hosts the
`tapescan-legal` repository. The app's `LegalLinks` constants
(`Sources/Services/PurchaseService.swift`) contain the literal `OWNER-INPUT`
host segment until this is done.

## Publish steps (one time, ~5 minutes)

1. Create a **public** GitHub repository named `tapescan-legal` under your
   account (no README, no .gitignore).
2. From this folder, push the four HTML files to its `main` branch:

   ```bash
   cd legal-site
   git init
   git add index.html privacy.html terms.html support.html
   git commit -m "TapeScan legal & support site"
   git branch -M main
   git remote add origin https://github.com/<github-username>/tapescan-legal.git
   git push -u origin main
   ```

   (Do this in a temp clone if you prefer not to nest a repo; only the four
   HTML files need to be pushed.)
3. On GitHub: repo → **Settings → Pages** → Source: **Deploy from a branch** →
   Branch: `main`, folder `/ (root)` → Save.
4. Wait for the Pages deploy (1–2 minutes), then open
   `https://<github-username>.github.io/tapescan-legal/` and click through all
   three documents.
5. Back in the app repo, replace both `OWNER-INPUT` occurrences in
   `Sources/Services/PurchaseService.swift` (`LegalLinks.terms` /
   `LegalLinks.privacy`) with `<github-username>`, rebuild, and verify the
   paywall Terms/Privacy links open the live pages.
6. In App Store Connect use the same URLs:
   - **Privacy Policy URL** → `.../tapescan-legal/privacy.html`
   - **Support URL** → `.../tapescan-legal/support.html`
```

- [ ] **Step 6: Verify the site locally.** Serve it and click every link on every page (all four pages cross-link; the only external link is Apple's standard EULA on terms.html):

```bash
cd /Users/faisalnurarif/Documents/PersonalApps/TapeMeasureARPro-iOS/legal-site
python3 -m http.server 8090
# open http://localhost:8090/ in a browser, click through index → privacy → terms → support
# Ctrl-C the server when done
```

Expected: all four pages render with the shared minimal style; no broken relative links; the mailto link shows faisal.arif@tuntun.co.id.

- [ ] **Step 7: Commit.**

```bash
cd /Users/faisalnurarif/Documents/PersonalApps/TapeMeasureARPro-iOS
git add legal-site
git commit -m "docs(legal): add TapeScan legal & support static site" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Final `LegalLinks` URLs + tappable Terms/Privacy text everywhere

`LegalLinks` switches to the GitHub Pages URL pattern (host marked `OWNER-INPUT` for the owner to set during publish — see Task 5's README). The signup consent copy becomes real tappable links via a new shared `LegalAgreementText` component. The paywall's Terms/Privacy buttons and the Settings rows (added by M3) already open `LegalLinks`, so they pick up the final URLs automatically.

**Files:**
- Modify: `Sources/Services/PurchaseService.swift` (the `enum LegalLinks` — was at `Sources/Screens/Rooms/PurchaseService.swift:20-25` pre-M3; M3 moved the file. Locate with `grep -rn "enum LegalLinks" Sources`)
- Create: `Sources/Components/LegalAgreementText.swift`
- Modify: `Sources/Screens/Auth/CreateAccountView.swift` (`footer` at lines 134–166, `termsText` at lines 168–175 — if M7 removed/renamed this view, see Step 4's locator)

- [ ] **Step 1: Point `LegalLinks` at the final hosted URLs.** Locate the enum (`grep -rn "enum LegalLinks" Sources`) and replace the whole `enum LegalLinks` declaration (including its doc comments) with:

```swift
/// Centralized legal URLs (Guideline 3.1.2 requires functional links to the
/// terms of use and privacy policy). These are the final hosted documents in
/// `legal-site/`, published to GitHub Pages. URL pattern:
///   https://<github-username>.github.io/tapescan-legal/<page>.html
/// OWNER-INPUT: replace the `OWNER-INPUT` host segment with the GitHub
/// username that publishes `legal-site/` (see legal-site/README.md, step 5).
public enum LegalLinks {
    /// Terms of Use — legal-site/terms.html on GitHub Pages.
    public static let terms = URL(string: "https://OWNER-INPUT.github.io/tapescan-legal/terms.html")!
    /// Privacy policy — legal-site/privacy.html on GitHub Pages.
    public static let privacy = URL(string: "https://OWNER-INPUT.github.io/tapescan-legal/privacy.html")!
}
```

- [ ] **Step 2: Create the shared tappable consent text component.** Create `Sources/Components/LegalAgreementText.swift` with exactly:

```swift
// LegalAgreementText.swift — tappable Terms & Privacy consent copy.
//
// Replaces the plain Text concatenation used on the signup consent row. The
// "Terms" and "Privacy Policy" runs carry `.link` attributes pointing at
// LegalLinks, so SwiftUI opens them via the environment's OpenURLAction —
// no Button wrapper required, and the surrounding copy stays non-interactive.

import SwiftUI

public struct LegalAgreementText: View {
    @Environment(\.theme) private var theme

    public init() {}

    public var body: some View {
        Text(attributed)
            .font(Theme.sans(12.5))
            .tint(theme.accent)
            .accessibilityLabel("I agree to the Terms and Privacy Policy")
    }

    private var attributed: AttributedString {
        var lead = AttributedString("I agree to the ")
        lead.foregroundColor = Theme.ink2
        var terms = AttributedString("Terms")
        terms.link = LegalLinks.terms
        terms.foregroundColor = theme.accent
        var middle = AttributedString(" and ")
        middle.foregroundColor = Theme.ink2
        var privacy = AttributedString("Privacy Policy")
        privacy.link = LegalLinks.privacy
        privacy.foregroundColor = theme.accent
        var trail = AttributedString(".")
        trail.foregroundColor = Theme.ink2
        return lead + terms + middle + privacy + trail
    }
}

#Preview {
    ZStack {
        Theme.screenBG
        LegalAgreementText()
            .environment(\.theme, Theme(accent: AccentOption.blue.color))
    }
    .frame(width: 402, height: 120)
}
```

- [ ] **Step 3: Regenerate the project (new file).**

```bash
xcodegen generate
```

- [ ] **Step 4: Use it on the signup consent row.** Locate the consent copy: `grep -rn "I agree to the" Sources --include="*.swift"`. In the file it lives in (pre-M7: `Sources/Screens/Auth/CreateAccountView.swift`), the consent row is a single `Button { agreedToTerms.toggle() }` whose label contains both the checkbox and the text — links cannot be tapped inside a button label, so split them. Replace the existing `footer` computed property AND delete the `termsText` computed property, so the footer reads:

```swift
    private var footer: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Button { agreedToTerms.toggle() } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(agreedToTerms ? theme.accent.withA(0.95)
                                                : Color.white.opacity(0.08))
                            .frame(width: 20, height: 20)
                        if agreedToTerms {
                            Icon("check", size: 13, weight: 3, color: .white)
                        }
                    }
                    .padding(.top, 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Agree to Terms and Privacy Policy")
                .accessibilityAddTraits(agreedToTerms ? .isSelected : [])

                LegalAgreementText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryButton(title: "Create Account") {
                showVerify = true
            }
            .accessibilityLabel("Create account")
            .opacity(agreedToTerms ? 1 : 0.5)
            .disabled(!agreedToTerms)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 36)
    }
```

If M7 merged the signup flow into a different view (the grep in this step tells you where), apply the identical split there: keep that view's checkbox toggle button (with its existing state variable and CTA wiring) as its own `Button`, and render `LegalAgreementText()` as a sibling in an `HStack(alignment: .top, spacing: 10)` exactly as above. If the grep returns no match at all (M7 removed consent copy entirely), add `LegalAgreementText()` directly beneath the email-flow CTA of the sign-in sheet with `.padding(.top, 10)` — the component is self-contained.

- [ ] **Step 5: Verify every legal-link surface reads `LegalLinks`.**

```bash
grep -rn "LegalLinks" Sources --include="*.swift"
```

Expected matches: the enum definition, `PaywallView` (`openURL(LegalLinks.terms)` / `openURL(LegalLinks.privacy)`), the M3 Settings rows, and `LegalAgreementText`. Any other hardcoded legal URL found by `grep -rn "apple.com/legal" Sources --include="*.swift"` must be removed (expected: zero matches after Step 1).

- [ ] **Step 6: Build verification.**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Simulator link check.** Launch the app in the booted simulator, open the signup/consent surface and the paywall, and tap Terms then Privacy on each. Expected: Safari opens `https://owner-input.github.io/tapescan-legal/terms.html` / `privacy.html` (a 404 until the owner publishes — the tap-through and URL shape are what is being verified here).

- [ ] **Step 8: Commit.**

```bash
git add Sources/Services/PurchaseService.swift Sources/Components/LegalAgreementText.swift Sources/Screens/Auth TapeMeasureARPro.xcodeproj
git commit -m "feat(legal): final legal URLs + tappable Terms/Privacy links" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

(If Step 4 edited a different auth file than `Sources/Screens/Auth`, add that path instead.)

---### Task 7: Final `PrivacyInfo.xcprivacy` review

Declare the truth post-M7: with optional accounts the app collects email, user content (measurements/rooms), purchase history, and a user ID — all linked to identity, all for app functionality only, no tracking. Keep the `UserDefaults` required-reason entry (added by M2 with reason `CA92.1`); if M2 did not add it, this task does.

**Files:**
- Modify: `Sources/Resources/PrivacyInfo.xcprivacy` (full replacement; file is currently the empty template)

- [ ] **Step 1: Replace the manifest.** Write `Sources/Resources/PrivacyInfo.xcprivacy` with exactly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- TapeScan does not track users (no cross-app/-site tracking, no IDFA). -->
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<!-- Collected only when the user opts into an account (backup & sync).
	     All types: linked to identity, NOT used for tracking, app functionality
	     only. Mirrors the App Store Connect nutrition-label answers. -->
	<key>NSPrivacyCollectedDataTypes</key>
	<array>
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypeEmailAddress</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<true/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
			</array>
		</dict>
		<dict>
			<!-- Measurements and room scans synced to the user's account. -->
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypeOtherUserContent</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<true/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypePurchaseHistory</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<true/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypeUserID</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<true/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
			</array>
		</dict>
	</array>
	<!-- Required-reason APIs: UserDefaults for app settings (CA92.1 = data
	     accessed only by this app). -->
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

Note: if M2 already added other `NSPrivacyAccessedAPITypes` entries (e.g. file-timestamp reasons), preserve them by merging — the `NSPrivacyCollectedDataTypes` array above fully replaces the old empty one either way.

- [ ] **Step 2: Lint the plist.**

```bash
plutil -lint Sources/Resources/PrivacyInfo.xcprivacy
```

Expected output: `Sources/Resources/PrivacyInfo.xcprivacy: OK`.

- [ ] **Step 3: Build verification (manifest is bundled, malformed manifests fail at build/archive).**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit.**

```bash
git add Sources/Resources/PrivacyInfo.xcprivacy
git commit -m "chore(privacy): declare collected data types in privacy manifest" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Real `README.md`, delete `GO-LIVE.md`, ASC-SETUP note

The template README/GO-LIVE describe a white-label stub product that no longer exists. Replace the README with real TapeScan developer docs; delete GO-LIVE.md; carry its only still-relevant content (owner publish/signing steps) into `docs/ASC-SETUP.md` as a clearly-delimited pending-inputs note for M9.

**Files:**
- Modify: `README.md` (full replacement)
- Delete: `GO-LIVE.md`
- Modify (or Create if M3 did not create it): `docs/ASC-SETUP.md`

- [ ] **Step 1: Replace `README.md`** with exactly:

```markdown
# TapeScan — iOS

AR tape measure & floor plan app for iPhone. ARKit multi-point measuring
(distance / area / volume / angle), RoomPlan room scanning, floor-plan exports
(PDF / PNG / SVG / USDZ / glTF), StoreKit 2 Pro purchases, and optional
Supabase-backed account sync. Bundle ID `co.tuntun.tapescan`.

## Requirements

| | |
|---|---|
| Xcode | 16+ (developed/verified on 26.1.1) |
| iOS deployment target | 17.0 |
| Project generator | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| Device features | LiDAR iPhone for room scan; measuring works on all ARKit iPhones (plane-detection fallback). Simulator runs the full UX with simulated AR. |

## Setup · build · run

```bash
brew install xcodegen            # once
xcodegen generate                # required after adding/renaming any file
open TapeMeasureARPro.xcodeproj  # scheme: TapeScan → ⌘R
```

Command line:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Tests

```bash
# Unit tests (TapeScanTests): domain math, converters, exporters, sync merge, theme mapping
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO \
  test -only-testing:TapeScanTests

# UI smoke tests (TapeScanUITests)
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO \
  test -only-testing:TapeScanUITests
```

## StoreKit testing (Simulator)

`TapeScan.storekit` at the repo root is wired into the shared TapeScan scheme,
so purchases work in the Simulator with no App Store Connect access. Products:

| Product ID | Type | Price |
|---|---|---|
| `tapescan.pro.monthly` | auto-renewing, 7-day trial | $4.99 / month |
| `tapescan.pro.annual` | auto-renewing, 7-day trial | $24.99 / year |
| `tapescan.pro.lifetime` | non-consumable | $59.99 |

`isPro` is derived from `Transaction.currentEntitlements` (never persisted).
Sandbox/device testing and App Store Connect product creation: see
`docs/ASC-SETUP.md`.

## Supabase (optional accounts & sync)

Accounts never gate the app; they enable backup/sync of measurements and rooms.

- Client config: `Sources/Resources/SupabaseConfig.swift` (project URL + anon
  key — the anon key is public by design; row-level security enforces access).
- Schema & RLS policies: SQL migrations under `supabase/migrations/`.
- Auth methods: Sign in with Apple (native), Google (OAuth), email OTP.
- Account deletion: in-app (Settings → Delete account) via the `delete_user()`
  RPC.

## Legal & privacy

- Hosted legal documents live in `legal-site/` — publish steps in
  `legal-site/README.md`. In-app URLs: `LegalLinks` in
  `Sources/Services/PurchaseService.swift`.
- `Sources/Resources/PrivacyInfo.xcprivacy` declares: email, user content
  (measurements/rooms), purchase history, user ID — linked, app functionality
  only, **no tracking**. Camera frames never leave the device.

## Project layout

```
Sources/App/          AppState, RootView, MainTabView, app entry
Sources/Theme/        Theme tokens (Dynamic Type aware sans/mono)
Sources/Components/   Reusable atoms (Chip, Reticle, FloorPlan, …)
Sources/Screens/      Auth / Onboarding / Measure / Rooms / Library
Sources/Domain/       MeasureTypes, MeasureMath, FloorPlanModel, converters
Sources/Persistence/  SwiftData records + ModelContainerFactory
Sources/Services/     AR / purchases / auth / sync / export services
Tests/                TapeScanTests (unit) · TapeScanUITests (smoke)
legal-site/           Static legal & support site (GitHub Pages)
docs/                 ASC-SETUP.md and design docs
```

## DEBUG launch arguments

`-uiPhase`, `-uiTab`, `-uiPro`, `-uiPaywall` jump the app to specific states
(DEBUG builds only; used by the UI smoke tests).
```

- [ ] **Step 2: Delete `GO-LIVE.md`.**

```bash
git rm GO-LIVE.md
```

- [ ] **Step 3: Carry pending owner steps into `docs/ASC-SETUP.md`.** If the file exists (M3 created it), append the section below verbatim at the end; if it does not exist, create it containing a top-level heading `# App Store Connect setup (TapeScan)`, one sentence — `Product-creation steps are owned by the M3/M9 plans; this file also tracks pending owner inputs.` — and then the section below:

```markdown
## Pending owner inputs (carried from the retired GO-LIVE.md — required before M9 submission)

- [ ] Publish `legal-site/` to GitHub Pages (follow `legal-site/README.md`),
      then replace both `OWNER-INPUT` host segments in
      `Sources/Services/PurchaseService.swift` (`LegalLinks`) with the GitHub
      username and rebuild.
- [ ] Enter the published URLs in App Store Connect:
      Privacy Policy URL → `.../tapescan-legal/privacy.html`,
      Support URL → `.../tapescan-legal/support.html`.
- [ ] App Privacy (nutrition label) answers must mirror
      `Sources/Resources/PrivacyInfo.xcprivacy`: Email Address, Other User
      Content (measurements/rooms), Purchase History, User ID — all linked to
      identity, app functionality, no tracking.
- [ ] Apple Team ID set as `DEVELOPMENT_TEAM` in `project.yml` (signing).
```

- [ ] **Step 4: Verification.** Confirm no references to the deleted doc remain:

```bash
grep -rn "GO-LIVE" README.md Sources docs legal-site --include="*" || echo "CLEAN"
```

Expected: `CLEAN` (the only permissible matches are inside `docs/superpowers/` historical specs/plans, which the command above does not flag as failures — if matches appear there, leave them; they are historical records).

- [ ] **Step 5: Commit.**

```bash
git add README.md docs/ASC-SETUP.md
git commit -m "docs: replace template README, retire GO-LIVE.md" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

(`git rm` already staged the deletion.)

---

### Task 9: Audit pass — scrub `TapeMeasure` brand literals and placeholder URLs

Final sweep so no template branding or placeholder URL ships. Known pre-M8 occurrences are listed with their exact fixes; M1/M7 may have already fixed some — the greps are the source of truth.

**Files:**
- Modify (as found by greps): `Sources/Screens/Onboarding/OnbPermissionView.swift` (line 47), `Sources/Screens/Library/SettingsView.swift` (lines 239, 265), `Sources/Screens/Onboarding/OnbWelcomeView.swift` (line 23), `Sources/App/AppState.swift` (line 1 comment), `Sources/App/TapeMeasureARProApp.swift` (rename, if M1 did not), auth screens with `studio.co` prompts

- [ ] **Step 1: Run the brand audit grep.**

```bash
grep -rn "TapeMeasure" Sources --include="*.swift"
```

Record every match. Apply these fixes for the known occurrences (skip any a prior milestone already fixed):

  - `Sources/Screens/Onboarding/OnbPermissionView.swift:47` — the permission body copy hardcodes the brand. Add below the existing `@Environment(\.theme) private var theme` property:
    ```swift
    @Environment(AppState.self) private var appState
    ```
    and replace the literal Text with:
    ```swift
            Text("\(appState.brand) uses your camera to detect surfaces and place measurement points. LiDAR is used automatically when your device supports it.")
    ```
  - `Sources/Screens/Library/SettingsView.swift:239` — `prompt: Text("TapeMeasure")` → `prompt: Text("TapeScan")`.
  - `Sources/Screens/Library/SettingsView.swift:265` — `{ brand = "TapeMeasure" }` → `{ brand = "TapeScan" }`.
  - `Sources/Screens/Onboarding/OnbWelcomeView.swift:23` — `(trimmed.isEmpty ? "TapeMeasure" : trimmed)` → `(trimmed.isEmpty ? "TapeScan" : trimmed)`.
  - `Sources/App/AppState.swift:113` — `public var brand: String = "TapeMeasure"` → `= "TapeScan"` (M1 owns this; fix here only if still present).
  - Header comments mentioning "TapeMeasure AR Pro" (e.g. `Sources/App/AppState.swift:1`) — replace the phrase with "TapeScan".

- [ ] **Step 2: Rename the app entry type if M1 left it.** Check:

```bash
grep -rn "struct TapeMeasureARProApp" Sources --include="*.swift"
```

If it matches, rename the struct to `TapeScanApp`, update the file's header comment to `// TapeScanApp.swift — SwiftUI App entry point.`, then:

```bash
git mv Sources/App/TapeMeasureARProApp.swift Sources/App/TapeScanApp.swift
xcodegen generate
```

If it does not match, skip this step.

- [ ] **Step 3: Placeholder URL & demo-identity audit.**

```bash
grep -rn "apple.com/legal\|example.com\|studio.co\|yourcompany\|TODO\|FIXME" Sources --include="*.swift"
```

Fixes for known pre-M8 occurrences (M7 owns the demo-identity removals; fix here only if still present):
  - `apple.com/legal` anywhere → must be gone after Task 6 (the only sanctioned Apple-EULA link is inside `legal-site/terms.html`, not Swift).
  - Email field prompts `placeholder: "you@studio.co"` (SignInView / CreateAccountView or their M7 successors) → `placeholder: "you@example.com"`.
  - Seeded identities `= "alex@studio.co"` / `= "Alex Rivera"` / `init(email: String = "alex@studio.co")` → empty string defaults (`= ""`); these are M7's responsibility — if found, replace with `""` and verify the affected screen still renders via the build step below.
  - `TODO`/`FIXME` matches: resolve or delete the comment (none are expected).

- [ ] **Step 4: OWNER-INPUT inventory (expected, not a failure).**

```bash
grep -rn "OWNER-INPUT" Sources legal-site docs --include="*"
```

Expected matches and ONLY these: the two `LegalLinks` URL constants + their doc comment in `Sources/Services/PurchaseService.swift`, the explanatory mentions in `legal-site/README.md`, and the pending-inputs checklist in `docs/ASC-SETUP.md`. These remain until the owner publishes the site (tracked as an owner input).

- [ ] **Step 5: Re-run the acceptance greps.**

```bash
grep -rn "TapeMeasure" Sources --include="*.swift" || echo "BRAND CLEAN"
grep -rn "apple.com/legal\|example.com\|studio.co" Sources --include="*.swift" || echo "URLS CLEAN"
```

Expected: `BRAND CLEAN` and `URLS CLEAN` (zero matches from both greps).

- [ ] **Step 6: Build + full unit-test verification.**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO \
  test -only-testing:TapeScanTests
```

Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit.**

```bash
git add -A Sources TapeMeasureARPro.xcodeproj
git commit -m "chore: scrub TapeMeasure brand literals and placeholder URLs" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Verification

### Simulator (full milestone check)

1. **Unit tests:**
   ```bash
   xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO \
     test -only-testing:TapeScanTests
   ```
   All pass, including the 10 `ThemeFontMappingTests`.
2. **Dynamic Type:** with the app installed on a booted iPhone 17 Pro simulator:
   ```bash
   xcrun simctl ui booted content_size accessibility-extra-large
   ```
   (Alternative: add launch argument `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL` to the TapeScan scheme.) Relaunch the app and walk Measure → Rooms/Paywall → Settings:
   - All text is visibly larger (fonts scale; at default `large` size the app is pixel-identical to pre-M8).
   - Paywall plan cards: titles/prices on one line (scaled), subtitles wrap, no clipped glyphs.
   - Measure HUD: chips grow vertically, telemetry strip stays legible.
   - Settings: subtitles wrap to two lines, detail values shrink-to-fit.
   - While the app is foregrounded, change the size again with `simctl` — the UI rebuilds with the new size (RootView `.id(typeSize)`).
   Reset: `xcrun simctl ui booted content_size large`.
3. **Reduce Motion:**
   ```bash
   xcrun simctl spawn booted defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
   ```
   (or Simulator Settings app → Accessibility → Motion → Reduce Motion ON), relaunch the app. The reticle pulse ring is a static faint ring, status dots are steady, the room-scan sweep is a parked static band, and the OTP caret is solid. Turn the setting off and confirm all four animate again.
4. **Legal links:** open the signup consent row and tap "Terms" then "Privacy Policy" — Safari opens the `…github.io/tapescan-legal/…` URLs (404 until published). Repeat from the paywall footer and the Settings legal rows.
5. **Legal site:** `cd legal-site && python3 -m http.server 8090`, click through all four pages and every internal link.
6. **Privacy manifest:** `plutil -lint Sources/Resources/PrivacyInfo.xcprivacy` → `OK`; visually confirm the four collected-data dicts and `NSPrivacyTracking = false`.
7. **Audit:** both acceptance greps from Task 9 Step 5 print `BRAND CLEAN` / `URLS CLEAN`; `grep -rn "repeatForever" Sources --include="*.swift"` shows exactly 4 matches, each behind a reduce-motion guard.
8. **Docs:** `README.md` describes TapeScan (no white-label/RevenueCat copy); `GO-LIVE.md` is gone; `docs/ASC-SETUP.md` contains the pending-owner-inputs checklist.

### Device / owner steps (after the owner supplies the GitHub username)

1. Follow `legal-site/README.md`: create the public `tapescan-legal` repo, push, enable Pages, and confirm `https://<username>.github.io/tapescan-legal/privacy.html`, `terms.html`, and `support.html` load over HTTPS.
2. Replace both `OWNER-INPUT` segments in `LegalLinks` (`Sources/Services/PurchaseService.swift`) with the username; rebuild; on a device tap Terms/Privacy from the paywall and the signup consent text — both live pages open.
3. On a physical iPhone, enable Settings → Accessibility → Motion → Reduce Motion and Display & Text Size → Larger Text (max accessibility size); re-walk Measure, Paywall, and Settings to confirm the same results as the Simulator checks 2–3.
4. Enter the privacy/support URLs and the matching App Privacy answers in App Store Connect (checklist in `docs/ASC-SETUP.md`).
