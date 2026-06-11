# M1 Foundation & Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Rename the white-label template to **TapeScan** (`co.tuntun.tapescan`) with production project plumbing — entitlements, shared scheme, bootstrap test targets, App-Store-compliant Info.plist, single-source brand string, DEBUG-fenced white-label surfaces, and a zero-warning build.

**Architecture:** This milestone touches only project metadata (`project.yml` → regenerated `TapeMeasureARPro.xcodeproj` via XcodeGen; the **project file name stays `TapeMeasureARPro.xcodeproj`** — only the target/scheme/product become `TapeScan`) plus four SwiftUI files. `AppState.defaultBrand` becomes the single brand literal that `AppState.brand`, the Settings `BrandField`, and the onboarding eyebrow all derive from. Two empty test targets (`TapeScanTests`, `TapeScanUITests`) bootstrap the test pyramid that M2–M9 build on.

**Tech Stack:** Swift 5.9 / SwiftUI / iOS 17.0 deployment target · XcodeGen 2.45.4 · XCTest + XCUITest · xcodebuild on Xcode 26.1.1 · Simulator "iPhone 17 Pro".

**Dependencies:** none (M1 is the root milestone).

**Verified starting state** (confirmed against the working tree at commit `986dacf` on 2026-06-10):

- Git repo exists; `git log --oneline` ends at `986dacf docs: add architecture contracts...`. `.gitignore` already covers `xcuserdata/`, `.build/`, `.DS_Store`.
- Current target/scheme: `TapeMeasureARPro`; no shared schemes exist in `TapeMeasureARPro.xcodeproj/xcshareddata/` (the scheme `xcodebuild -list` shows is auto-generated).
- A clean build (`xcodebuild ... clean build`) produces **exactly 6 compiler warnings**, all `backward matching of the unlabeled trailing closure is deprecated; label the argument with 'accessory'` at `Sources/Screens/Library/SettingsView.swift` lines **129, 134, 159, 164, 179, 190**. (The `DRow` call at line 140 does NOT warn because its `action:` argument is labeled.)
- xcodebuild also prints one stderr line from `appintentsmetadataprocessor` ("Metadata extraction skipped. No AppIntents.framework dependency found."). This is tool chatter, **not** a compiler warning — it never appears in Xcode's Issue navigator. All "zero warnings" checks below filter it explicitly.
- The exact `project.yml` prescribed in Tasks 1 and 3 was validated end-to-end with XcodeGen 2.45.4 in a sandbox during planning: it generates targets `TapeScan`/`TapeScanTests`/`TapeScanUITests`, writes `xcshareddata/xcschemes/TapeScan.xcscheme`, auto-sets `TEST_HOST`/`BUNDLE_LOADER`/`TEST_TARGET_NAME`, and does **not** copy the `.entitlements` file into any build phase.
- Extra brand literals found during planning (beyond the two named in the milestone scope): `Sources/Screens/Onboarding/OnbPermissionView.swift:47` ("TapeMeasure uses your camera…") and the `BrandField` prompt at `SettingsView.swift:239`. Both are fixed in Task 4 — leaving them would ship the old brand in user-facing copy, contradicting the rename. `NSCameraUsageDescription` in Info.plist has the same literal and is fixed in Task 2.

All commands below run from the repo root: `/Users/faisalnurarif/Documents/PersonalApps/TapeMeasureARPro-iOS`.

---

### Task 1: TapeScan entitlements + product rename + shared scheme in project.yml

**Files:**
- Create: `Sources/Resources/TapeScan.entitlements`
- Modify: `project.yml` (full rewrite; current file is 34 lines)
- Regenerated: `TapeMeasureARPro.xcodeproj/project.pbxproj`, `TapeMeasureARPro.xcodeproj/xcshareddata/xcschemes/TapeScan.xcscheme` (via `xcodegen generate`)
- Test: build verification (config task — no unit test)

- [ ] **Step 1: Create the entitlements file.** Write `Sources/Resources/TapeScan.entitlements` with exactly this content (In-App Purchase + Sign in with Apple, per the contracts doc "Project identity (M1)"):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
	<key>com.apple.developer.in-app-purchase</key>
	<true/>
</dict>
</plist>
```

- [ ] **Step 2: Lint the entitlements file.** Run:

```bash
plutil -lint Sources/Resources/TapeScan.entitlements
```

Expected output: `Sources/Resources/TapeScan.entitlements: OK`

- [ ] **Step 3: Rewrite project.yml.** Replace the entire contents of `project.yml` with exactly this (changes vs. current: `bundleIdPrefix` → `co.tuntun`; commented `DEVELOPMENT_TEAM` owner-input placeholder; target renamed `TapeMeasureARPro` → `TapeScan`; `PRODUCT_BUNDLE_IDENTIFIER` → `co.tuntun.tapescan`; `PRODUCT_NAME` → `TapeScan`; new `CODE_SIGN_ENTITLEMENTS`; new `schemes:` block so the scheme is shared/committed. `MARKETING_VERSION` stays `"1.0"`; `CODE_SIGNING_ALLOWED: NO` stays so Simulator builds need no certificate):

```yaml
name: TapeMeasureARPro
options:
  bundleIdPrefix: co.tuntun
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "5.0"
    SWIFT_STRICT_CONCURRENCY: minimal
    DEVELOPMENT_LANGUAGE: en
    CODE_SIGNING_ALLOWED: NO
    CODE_SIGNING_REQUIRED: NO
    # Owner input: Apple Developer Team ID (Apple Developer portal → Membership).
    # Uncomment and flip CODE_SIGNING_ALLOWED / CODE_SIGNING_REQUIRED to YES for
    # device builds and archiving. Simulator builds stay unsigned on purpose so
    # CI and local Simulator verification need no certificates.
    # DEVELOPMENT_TEAM: REPLACE_WITH_TEAM_ID

targets:
  TapeScan:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - Sources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: co.tuntun.tapescan
        PRODUCT_NAME: TapeScan
        INFOPLIST_FILE: Sources/Resources/Info.plist
        GENERATE_INFOPLIST_FILE: NO
        CODE_SIGN_ENTITLEMENTS: Sources/Resources/TapeScan.entitlements
        TARGETED_DEVICE_FAMILY: "1"
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        ENABLE_PREVIEWS: YES
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
        SWIFT_STRICT_CONCURRENCY: minimal

schemes:
  TapeScan:
    build:
      targets:
        TapeScan: all
    run:
      config: Debug
    profile:
      config: Release
    analyze:
      config: Debug
    archive:
      config: Release
```

(The `test:` section of the scheme is added in Task 3 together with the test targets it references.)

- [ ] **Step 4: Regenerate the project.** Run:

```bash
xcodegen generate
```

Expected output ends with: `Created project at /Users/faisalnurarif/Documents/PersonalApps/TapeMeasureARPro-iOS/TapeMeasureARPro.xcodeproj`

- [ ] **Step 5: Verify the rename and the shared scheme.** Run:

```bash
xcodebuild -list -project TapeMeasureARPro.xcodeproj
ls TapeMeasureARPro.xcodeproj/xcshareddata/xcschemes/
```

Expected: targets list shows `TapeScan` (no `TapeMeasureARPro` target); schemes list shows `TapeScan`; `ls` shows `TapeScan.xcscheme`.

- [ ] **Step 6: Build with the new scheme.** Run:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`. The 6 pre-existing `DRow` deprecation warnings will appear (everything recompiles under the new target) — they are fixed in Task 5, not here.

- [ ] **Step 7: Commit.** Run:

```bash
git add project.yml Sources/Resources/TapeScan.entitlements TapeMeasureARPro.xcodeproj
git commit -m "chore: rename product to TapeScan with entitlements and shared scheme

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Info.plist — App Store compliance + display identity

**Files:**
- Modify: `Sources/Resources/Info.plist` (current file is 47 lines; full replacement below). Changes: `CFBundleDisplayName` line 8 `TapeMeasure` → `TapeScan`; `NSCameraUsageDescription` line 26 reworded for TapeScan; add `ITSAppUsesNonExemptEncryption=false`; add `UIRequiredDeviceCapabilities=[arkit]`; delete `UIStatusBarStyle` (lines 41–42, inert — status bars are view-controller-based since iOS 13); replace the invalid key `UIUserInterfaceStyleDefault` (lines 43–44) with `UIUserInterfaceStyle=Dark`.
- Test: plist lint + build verification (config task — no unit test)

- [ ] **Step 1: Replace Sources/Resources/Info.plist** with exactly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>TapeScan</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>ITSAppUsesNonExemptEncryption</key>
	<false/>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>NSCameraUsageDescription</key>
	<string>TapeScan uses the camera to detect surfaces and place measurement points.</string>
	<key>UILaunchScreen</key>
	<dict>
		<key>UIColorName</key>
		<string></string>
	</dict>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UIApplicationSupportsMultipleScenes</key>
		<false/>
	</dict>
	<key>UIRequiredDeviceCapabilities</key>
	<array>
		<string>arkit</string>
	</array>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
	<key>UIUserInterfaceStyle</key>
	<string>Dark</string>
</dict>
</plist>
```

- [ ] **Step 2: Lint.** Run:

```bash
plutil -lint Sources/Resources/Info.plist
```

Expected output: `Sources/Resources/Info.plist: OK`

- [ ] **Step 3: Build.** (No `xcodegen generate` needed — only file *contents* changed; the project structure is untouched.) Run:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit.** Run:

```bash
git add Sources/Resources/Info.plist
git commit -m "chore: harden Info.plist for App Store compliance

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Bootstrap TapeScanTests (unit) and TapeScanUITests (XCUITest) targets

**Files:**
- Create: `Tests/TapeScanTests/TapeScanTests.swift`, `Tests/TapeScanUITests/SmokeTests.swift` (paths per the contracts doc "Directory layout")
- Modify: `project.yml` (append two targets; add `test:` to the `TapeScan` scheme; full final file below)
- Regenerated: `TapeMeasureARPro.xcodeproj` (via `xcodegen generate`)
- Test: the two bootstrap tests themselves

- [ ] **Step 1: Create the unit-test bootstrap file.** Write `Tests/TapeScanTests/TapeScanTests.swift` with exactly:

```swift
// TapeScanTests.swift — bootstrap unit-test target (M1).
//
// One trivial test proving the TapeScanTests bundle builds, links the TapeScan
// module via @testable import, and runs in the Simulator. Real domain tests
// (MeasureMath, UnitFormat, converters, sync merge) arrive with M2+.

import XCTest
@testable import TapeScan

final class TapeScanTests: XCTestCase {

    func testMeasureUnitProvidesBothSystems() {
        XCTAssertEqual(MeasureUnit.allCases.count, 2)
        XCTAssertEqual(MeasureUnit.metric.title, "Metric")
        XCTAssertEqual(MeasureUnit.imperial.title, "Imperial")
    }
}
```

(`MeasureUnit` is the existing public enum in `Sources/App/AppState.swift:9-15`; it is non-isolated, so no `@MainActor` is needed here.)

- [ ] **Step 2: Create the UI-test bootstrap file.** Write `Tests/TapeScanUITests/SmokeTests.swift` with exactly:

```swift
// SmokeTests.swift — bootstrap XCUITest target (M1).
//
// One trivial launch test proving the TapeScanUITests bundle builds and can
// drive the app. Real smoke flows (onboarding, paywall, settings, history)
// arrive with M9, riding the existing DEBUG-only -ui* launch arguments
// handled by AppState.bootstrapped().

import XCTest

final class SmokeTests: XCTestCase {

    @MainActor
    func testAppLaunchesToMainTabs() throws {
        let app = XCUIApplication()
        // DEBUG-only launch arg (see AppState.bootstrapped): skip auth + onboarding.
        app.launchArguments = ["-uiPhase", "main"]
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }
}
```

- [ ] **Step 3: Add the test targets and scheme test action to project.yml.** Replace the entire contents of `project.yml` with exactly (vs. Task 1's version: two new targets appended under `targets:`, and a `test:` section inserted into the `TapeScan` scheme):

```yaml
name: TapeMeasureARPro
options:
  bundleIdPrefix: co.tuntun
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "5.0"
    SWIFT_STRICT_CONCURRENCY: minimal
    DEVELOPMENT_LANGUAGE: en
    CODE_SIGNING_ALLOWED: NO
    CODE_SIGNING_REQUIRED: NO
    # Owner input: Apple Developer Team ID (Apple Developer portal → Membership).
    # Uncomment and flip CODE_SIGNING_ALLOWED / CODE_SIGNING_REQUIRED to YES for
    # device builds and archiving. Simulator builds stay unsigned on purpose so
    # CI and local Simulator verification need no certificates.
    # DEVELOPMENT_TEAM: REPLACE_WITH_TEAM_ID

targets:
  TapeScan:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - Sources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: co.tuntun.tapescan
        PRODUCT_NAME: TapeScan
        INFOPLIST_FILE: Sources/Resources/Info.plist
        GENERATE_INFOPLIST_FILE: NO
        CODE_SIGN_ENTITLEMENTS: Sources/Resources/TapeScan.entitlements
        TARGETED_DEVICE_FAMILY: "1"
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        ENABLE_PREVIEWS: YES
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
        SWIFT_STRICT_CONCURRENCY: minimal

  TapeScanTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - Tests/TapeScanTests
    dependencies:
      - target: TapeScan
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: co.tuntun.tapescan.tests
        GENERATE_INFOPLIST_FILE: YES

  TapeScanUITests:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - Tests/TapeScanUITests
    dependencies:
      - target: TapeScan
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: co.tuntun.tapescan.uitests
        GENERATE_INFOPLIST_FILE: YES

schemes:
  TapeScan:
    build:
      targets:
        TapeScan: all
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - TapeScanTests
        - TapeScanUITests
    profile:
      config: Release
    analyze:
      config: Debug
    archive:
      config: Release
```

(XcodeGen auto-derives `TEST_HOST`/`BUNDLE_LOADER` for `TapeScanTests` and `TEST_TARGET_NAME=TapeScan` for `TapeScanUITests` from the `dependencies:` entries — verified during planning.)

- [ ] **Step 4: Regenerate.** Run:

```bash
xcodegen generate
```

Expected output ends with `Created project at .../TapeMeasureARPro.xcodeproj`. Then confirm all three targets exist:

```bash
xcodebuild -list -project TapeMeasureARPro.xcodeproj
```

Expected targets: `TapeScan`, `TapeScanTests`, `TapeScanUITests`; scheme: `TapeScan`.

- [ ] **Step 5: Run the full test suite.** (First run boots the Simulator — allow up to 10 minutes.) Run:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test
```

Expected output includes `Test Suite 'TapeScanTests' passed`, `Test Suite 'SmokeTests' passed`, and ends with `** TEST SUCCEEDED **` (2 tests, 0 failures).

- [ ] **Step 6: Commit.** Run:

```bash
git add project.yml Tests TapeMeasureARPro.xcodeproj
git commit -m "test: bootstrap TapeScanTests and TapeScanUITests targets

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Single-source the brand — AppState.defaultBrand = "TapeScan" (TDD)

**Files:**
- Create: `Tests/TapeScanTests/AppStateBrandTests.swift`
- Modify: `Sources/App/AppState.swift` (lines 1, 111–113), `Sources/Screens/Library/SettingsView.swift` (lines 237–239, 263–266), `Sources/Screens/Onboarding/OnbWelcomeView.swift` (lines 8, 20–24, 110–111), `Sources/Screens/Onboarding/OnbPermissionView.swift` (lines 16–19, 47)
- Regenerated: `TapeMeasureARPro.xcodeproj` (new test file requires `xcodegen generate`)
- Test: `AppStateBrandTests`

- [ ] **Step 1: Write the failing test.** Create `Tests/TapeScanTests/AppStateBrandTests.swift` with exactly:

```swift
// AppStateBrandTests.swift — brand single-source contract (M1).
//
// TapeScan ships with exactly one default-brand literal: AppState.defaultBrand.
// AppState.brand defaults to it; SettingsView's BrandField fallback and the
// onboarding eyebrow both derive from it. No other "TapeScan" brand literal
// may exist in Sources (enforced by the grep check in this task's plan).

import XCTest
@testable import TapeScan

final class AppStateBrandTests: XCTestCase {

    @MainActor
    func testDefaultBrandIsTapeScan() {
        XCTAssertEqual(AppState.defaultBrand, "TapeScan")
        XCTAssertEqual(AppState().brand, "TapeScan")
    }
}
```

(`@MainActor` because `AppState` is a `@MainActor @Observable` class — see `Sources/App/AppState.swift:107-109`. XCTest invokes synchronous test methods on the main thread, so this runs correctly.)

- [ ] **Step 2: Regenerate so the new file joins the test target.** Run:

```bash
xcodegen generate
```

Expected output ends with `Created project at .../TapeMeasureARPro.xcodeproj`.

- [ ] **Step 3: Run the test — confirm it fails (red).** Run:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test -only-testing:TapeScanTests
```

Expected failure: the test target fails to **compile** with `error: type 'AppState' has no member 'defaultBrand'` at `Tests/TapeScanTests/AppStateBrandTests.swift`, and xcodebuild ends with `** TEST FAILED **` (build error counts as red — `defaultBrand` does not exist yet, and `AppState().brand` is still `"TapeMeasure"`).

- [ ] **Step 4: Implement the minimal AppState change.** In `Sources/App/AppState.swift`, apply two edits.

Edit 1 — file header comment (line 1), old:

```swift
// AppState.swift — TapeMeasure AR Pro
```

new:

```swift
// AppState.swift — TapeScan
```

Edit 2 — branding section (lines 111–113), old:

```swift
    // MARK: - Branding
    /// Product brand string. Constant for now, but kept on state so it is reskin-ready.
    public var brand: String = "TapeMeasure"
```

new:

```swift
    // MARK: - Branding
    /// Canonical product brand — the single source for every brand literal in
    /// the app (wordmark, Pro card, onboarding eyebrow, BrandField fallback).
    public static let defaultBrand = "TapeScan"
    /// Product brand string. Defaults to ``defaultBrand``; mutable so the
    /// DEBUG-only brand field in Settings can live-preview a reskin.
    public var brand: String = AppState.defaultBrand
```

- [ ] **Step 5: Run the test — confirm it passes (green).** Run:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test -only-testing:TapeScanTests
```

Expected: `Test Suite 'AppStateBrandTests' passed`, `Test Suite 'TapeScanTests' passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Point the Settings BrandField at the single source.** In `Sources/Screens/Library/SettingsView.swift`, apply two edits.

Edit 1 — the `TextField` prompt (lines 237–239), old:

```swift
        TextField("",
                  text: $brand,
                  prompt: Text("TapeMeasure").foregroundColor(Theme.ink3))
```

new:

```swift
        TextField("",
                  text: $brand,
                  prompt: Text(AppState.defaultBrand).foregroundColor(Theme.ink3))
```

Edit 2 — the blank-input fallback (lines 263–266), old:

```swift
    /// Collapse all-whitespace input back to the default brand.
    private func normalize() {
        if brand.trimmingCharacters(in: .whitespaces).isEmpty { brand = "TapeMeasure" }
    }
```

new:

```swift
    /// Collapse all-whitespace input back to the default brand.
    private func normalize() {
        if brand.trimmingCharacters(in: .whitespaces).isEmpty { brand = AppState.defaultBrand }
    }
```

- [ ] **Step 7: Point the onboarding eyebrow at the single source.** In `Sources/Screens/Onboarding/OnbWelcomeView.swift`, apply three edits.

Edit 1 — header comment (line 8), old:

```swift
//   • Copy block: mono kicker "TAPEMEASURE AR PRO", 30-pt headline, three
```

new:

```swift
//   • Copy block: mono kicker "TAPESCAN AR PRO", 30-pt headline, three
```

Edit 2 — the `brandName` computed property (lines 20–24), old:

```swift
    /// Uppercased brand for the eyebrow; blank brand falls back to "TAPEMEASURE".
    private var brandName: String {
        let trimmed = appState.brand.trimmingCharacters(in: .whitespaces)
        return (trimmed.isEmpty ? "TapeMeasure" : trimmed).uppercased()
    }
```

new:

```swift
    /// Uppercased brand for the eyebrow; blank brand falls back to the default.
    private var brandName: String {
        let trimmed = appState.brand.trimmingCharacters(in: .whitespaces)
        return (trimmed.isEmpty ? AppState.defaultBrand : trimmed).uppercased()
    }
```

Edit 3 — the stale inline comment (lines 110–111), old:

```swift
            // Brand-derived eyebrow: "{BRAND} AR PRO", uppercased. With the default
            // brand this renders "TAPEMEASURE AR PRO" — identical to the source.
```

new:

```swift
            // Brand-derived eyebrow: "{BRAND} AR PRO", uppercased. With the default
            // brand this renders "TAPESCAN AR PRO".
```

- [ ] **Step 8: Fix the extra brand literal in the permission primer.** In `Sources/Screens/Onboarding/OnbPermissionView.swift`, apply two edits. (This literal is user-facing onboarding copy; its `#Preview` already injects `AppState()`, so adding the environment read is safe.)

Edit 1 — add the AppState environment (lines 16–19), old:

```swift
struct OnbPermissionView: View {
    @Environment(\.theme) private var theme

    var onContinue: () -> Void = {}
```

new:

```swift
struct OnbPermissionView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    var onContinue: () -> Void = {}
```

Edit 2 — the body copy (line 47, now line 48 after Edit 1), old:

```swift
            Text("TapeMeasure uses your camera to detect surfaces and place measurement points. LiDAR is used automatically when your device supports it.")
```

new:

```swift
            Text("\(appState.brand) uses your camera to detect surfaces and place measurement points. LiDAR is used automatically when your device supports it.")
```

- [ ] **Step 9: Verify no brand string literals remain.** Run:

```bash
grep -rn '"TapeMeasure' Sources --include="*.swift"
```

Expected: **no output** (exit code 1). Then run:

```bash
grep -rn '"TapeScan"' Sources --include="*.swift"
```

Expected: exactly **one** match — `Sources/App/AppState.swift` (`public static let defaultBrand = "TapeScan"`).

- [ ] **Step 10: Run tests + build, then commit.** Run:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test -only-testing:TapeScanTests
```

Expected: `** TEST SUCCEEDED **`. Then:

```bash
git add Sources/App/AppState.swift Sources/Screens/Library/SettingsView.swift Sources/Screens/Onboarding/OnbWelcomeView.swift Sources/Screens/Onboarding/OnbPermissionView.swift Tests/TapeScanTests/AppStateBrandTests.swift TapeMeasureARPro.xcodeproj
git commit -m "feat: single-source TapeScan brand via AppState.defaultBrand

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Fix the 6 DRow trailing-closure deprecation warnings

**Files:**
- Modify: `Sources/Screens/Library/SettingsView.swift` — the six `DRow` call sites that warn (lines 129, 134, 159, 164, 179, 190; Task 4 only touched lines below 237, so these numbers still hold). The fix labels each unlabeled trailing closure with `accessory:` (the `DRow` initializer in `Sources/Screens/Library/GroupedList.swift:68-84` declares `@ViewBuilder accessory:` after the defaulted `action:` parameter, which is what triggers backward matching). Each edit keeps the same line count, so later line references stay stable. No behavior change.
- Test: clean-build warning check (mechanical relabel — no unit test)

- [ ] **Step 1: Fix "Units" (line 129).** Old:

```swift
            DRow(icon: "ruler2", title: "Units") {
                IOSSegmented(options: MeasureUnit.allCases,
                             selection: unit) { $0.title }
                    .accessibilityLabel("Units")
            }
```

New:

```swift
            DRow(icon: "ruler2", title: "Units", accessory: {
                IOSSegmented(options: MeasureUnit.allCases,
                             selection: unit) { $0.title }
                    .accessibilityLabel("Units")
            })
```

- [ ] **Step 2: Fix "Point snapping" (line 134).** Old:

```swift
            DRow(icon: "pin", title: "Point snapping") {
                IOSToggle(isOn: $pointSnapping)
                    .accessibilityLabel("Point snapping")
                    .accessibilityValue(pointSnapping ? "On" : "Off")
            }
```

New:

```swift
            DRow(icon: "pin", title: "Point snapping", accessory: {
                IOSToggle(isOn: $pointSnapping)
                    .accessibilityLabel("Point snapping")
                    .accessibilityValue(pointSnapping ? "On" : "Off")
            })
```

- [ ] **Step 3: Fix "LiDAR depth" (line 159).** Old:

```swift
            DRow(icon: "lidar",
                 title: "LiDAR depth",
                 subtitle: lidar.wrappedValue
                    ? "Auto · device supported"
                    : "Off · visual-inertial fallback") {
                IOSToggle(isOn: lidar)
                    .accessibilityLabel("LiDAR depth")
                    .accessibilityValue(lidar.wrappedValue ? "On" : "Off")
            }
```

New:

```swift
            DRow(icon: "lidar",
                 title: "LiDAR depth",
                 subtitle: lidar.wrappedValue
                    ? "Auto · device supported"
                    : "Off · visual-inertial fallback", accessory: {
                IOSToggle(isOn: lidar)
                    .accessibilityLabel("LiDAR depth")
                    .accessibilityValue(lidar.wrappedValue ? "On" : "Off")
            })
```

- [ ] **Step 4: Fix "Plane detection" (line 164).** Old:

```swift
            DRow(icon: "grid", title: "Plane detection", last: true) {
                IOSSegmented(options: PlaneMode.allCases,
                             selection: $planeDetection) { $0.rawValue }
                    .accessibilityLabel("Plane detection")
            }
```

New:

```swift
            DRow(icon: "grid", title: "Plane detection", last: true, accessory: {
                IOSSegmented(options: PlaneMode.allCases,
                             selection: $planeDetection) { $0.rawValue }
                    .accessibilityLabel("Plane detection")
            })
```

- [ ] **Step 5: Fix "Accent color" (line 179).** Old:

```swift
            DRow(icon: "grid", title: "Accent color") {
                HStack(spacing: 10) {
                    ForEach(AccentOption.allCases) { option in
                        AccentSwatch(option: option,
                                     selected: accent == option) {
                            setAccent(option)
                        }
                    }
                }
            }
```

New:

```swift
            DRow(icon: "grid", title: "Accent color", accessory: {
                HStack(spacing: 10) {
                    ForEach(AccentOption.allCases) { option in
                        AccentSwatch(option: option,
                                     selected: accent == option) {
                            setAccent(option)
                        }
                    }
                }
            })
```

- [ ] **Step 6: Fix "Brand name" (line 190).** Old:

```swift
            DRow(icon: "ruler2", title: "Brand name", last: true) {
                BrandField(brand: brand)
            }
```

New:

```swift
            DRow(icon: "ruler2", title: "Brand name", last: true, accessory: {
                BrandField(brand: brand)
            })
```

- [ ] **Step 7: Verify zero compiler warnings on a clean build.** Run:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO clean build 2>&1 | grep "warning:" | grep -v "appintentsmetadataprocessor"
```

Expected: **no output** (grep exits 1). The only filtered line is the `appintentsmetadataprocessor … No AppIntents.framework dependency found` stderr log, which is tool chatter and not a compiler diagnostic. Also confirm the build itself succeeded:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit.** Run:

```bash
git add Sources/Screens/Library/SettingsView.swift
git commit -m "fix: label DRow accessory closures to silence deprecation warnings

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: DEBUG-fence the white-label surfaces (BrandField row + HUD style picker)

**Files:**
- Modify: `Sources/Screens/Library/SettingsView.swift` — `themeGroup` (lines 174–194 after Task 5; Task 5 edits preserved line counts), `Sources/Screens/Measure/MeasureView.swift` — header comment (lines 3–7), `body` (lines 52–58), `stylePicker` (lines 69–97)
- Test: Debug vs. Release binary checks via `strings` + full test suite (UI/config task — no unit test)

- [ ] **Step 1: Fence the Brand-name row in Settings.** In `Sources/Screens/Library/SettingsView.swift`, replace the whole `themeGroup` function (after Task 5 it reads exactly like the "old" block below). Old:

```swift
    private func themeGroup(accent: AccentOption,
                            setAccent: @escaping (AccentOption) -> Void,
                            brand: Binding<String>) -> some View {
        DListSection(header: "Theme") {
            // Accent swatch picker — 5 options in design order.
            DRow(icon: "grid", title: "Accent color", accessory: {
                HStack(spacing: 10) {
                    ForEach(AccentOption.allCases) { option in
                        AccentSwatch(option: option,
                                     selected: accent == option) {
                            setAccent(option)
                        }
                    }
                }
            })
            // Brand-name field — drives the wordmark / Pro card / auth lockup.
            DRow(icon: "ruler2", title: "Brand name", last: true, accessory: {
                BrandField(brand: brand)
            })
        }
    }
```

New:

```swift
    private func themeGroup(accent: AccentOption,
                            setAccent: @escaping (AccentOption) -> Void,
                            brand: Binding<String>) -> some View {
        // The brand-name field is a white-label/dev surface, not a user feature:
        // it ships DEBUG-only. In Release the accent row is the section's last
        // row, so it must suppress its bottom hairline.
        #if DEBUG
        let accentIsLast = false
        #else
        let accentIsLast = true
        #endif
        return DListSection(header: "Theme") {
            // Accent swatch picker — 5 options in design order.
            DRow(icon: "grid", title: "Accent color", last: accentIsLast, accessory: {
                HStack(spacing: 10) {
                    ForEach(AccentOption.allCases) { option in
                        AccentSwatch(option: option,
                                     selected: accent == option) {
                            setAccent(option)
                        }
                    }
                }
            })
            #if DEBUG
            // Brand-name field — drives the wordmark / Pro card / auth lockup.
            DRow(icon: "ruler2", title: "Brand name", last: true, accessory: {
                BrandField(brand: brand)
            })
            #endif
        }
    }
```

- [ ] **Step 2: Fence the HUD style picker in the Measure host.** In `Sources/Screens/Measure/MeasureView.swift`, apply three edits.

Edit 1 — header comment (lines 3–7), old:

```swift
// The design ships THREE visual directions of the live AR Measure screen
// (Precision HUD / Minimal Focus / Pro Console). This host makes all three
// reachable at runtime via a small floating "HUD style" picker pinned to the
// top edge, so reviewers can compare directions without rebuilding — while the
// chosen direction renders full-bleed underneath.
```

new:

```swift
// The design ships THREE visual directions of the live AR Measure screen
// (Precision HUD / Minimal Focus / Pro Console). The shipped direction is
// "Precision" (MeasureAView). In DEBUG builds a small floating "HUD style"
// picker pinned to the top edge keeps all three reachable for design review;
// Release builds render Precision full-bleed with no picker.
```

Edit 2 — `body` (lines 52–58), old:

```swift
    public var body: some View {
        ZStack(alignment: .top) {
            direction
            stylePicker
        }
        .background(Theme.cameraBG.ignoresSafeArea())
    }
```

new:

```swift
    public var body: some View {
        ZStack(alignment: .top) {
            direction
            #if DEBUG
            stylePicker
            #endif
        }
        .background(Theme.cameraBG.ignoresSafeArea())
    }
```

Edit 3 — wrap the `stylePicker` property in the fence. Old (lines 69–71 pre-edit):

```swift
    /// Floating glass segmented picker for the HUD style, top-center, below the
    /// status bar. Kept compact so it sits above each direction's own top HUD.
    private var stylePicker: some View {
```

new:

```swift
    #if DEBUG
    /// Floating glass segmented picker for the HUD style, top-center, below the
    /// status bar. DEBUG-only design-review tool — never user-facing in Release.
    private var stylePicker: some View {
```

and old (the property's closing lines, 96–98 pre-edit — note the final `}` on its own line closes `struct MeasureView`):

```swift
        .allowsHitTesting(true)
    }
}
```

new:

```swift
        .allowsHitTesting(true)
    }
    #endif
}
```

- [ ] **Step 3: Build Debug into a known DerivedData path and check the fenced strings are present.** Run:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/tapescan-dd-debug build
strings /tmp/tapescan-dd-debug/Build/Products/Debug-iphonesimulator/TapeScan.app/TapeScan | grep -c "Brand name"
strings /tmp/tapescan-dd-debug/Build/Products/Debug-iphonesimulator/TapeScan.app/TapeScan | grep -c "HUD style"
```

Expected: `** BUILD SUCCEEDED **`, then both `grep -c` counts are **≥ 1** (the literals exist in the Debug binary).

- [ ] **Step 4: Build Release and check the fenced strings are absent.** Run:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/tapescan-dd-release build
strings /tmp/tapescan-dd-release/Build/Products/Release-iphonesimulator/TapeScan.app/TapeScan | grep -c "Brand name"
strings /tmp/tapescan-dd-release/Build/Products/Release-iphonesimulator/TapeScan.app/TapeScan | grep -c "HUD style"
```

Expected: `** BUILD SUCCEEDED **` (this also proves the Release configuration compiles with the fences), then both `grep -c` print `0` (grep exits 1). Clean up: `rm -rf /tmp/tapescan-dd-debug /tmp/tapescan-dd-release`.

- [ ] **Step 5: Run the full test suite (Debug — UI smoke must still pass with the fences in).** Run:

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test
```

Expected: `** TEST SUCCEEDED **` (3 tests: `testMeasureUnitProvidesBothSystems`, `testDefaultBrandIsTapeScan`, `testAppLaunchesToMainTabs`).

- [ ] **Step 6: Commit.** Run:

```bash
git add Sources/Screens/Library/SettingsView.swift Sources/Screens/Measure/MeasureView.swift
git commit -m "chore: DEBUG-fence brand field and HUD style picker

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Verification

All M1 acceptance criteria are verifiable in the Simulator. No device or signing is required (the `DEVELOPMENT_TEAM` placeholder stays commented until the owner supplies the Team ID).

### Simulator — automated checks

1. **Zero-warning clean build (Debug):**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO clean build 2>&1 | grep -E "warning:|error:" | grep -v "appintentsmetadataprocessor"
```

Expected: no output. (The single filtered `appintentsmetadataprocessor` stderr line is tool chatter, not a compiler diagnostic.)

2. **Full test suite:**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test
```

Expected: `** TEST SUCCEEDED **` — `TapeScanTests` (2 tests) and `TapeScanUITests` (1 test) all pass.

3. **Identity & compliance keys in the built product:**

```bash
xcodebuild -project TapeMeasureARPro.xcodeproj -scheme TapeScan -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/tapescan-verify build
APP=/tmp/tapescan-verify/Build/Products/Debug-iphonesimulator/TapeScan.app
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" -c "Print :CFBundleDisplayName" -c "Print :CFBundleShortVersionString" -c "Print :ITSAppUsesNonExemptEncryption" -c "Print :UIUserInterfaceStyle" -c "Print :UIRequiredDeviceCapabilities:0" "$APP/Info.plist"
/usr/libexec/PlistBuddy -c "Print :UIStatusBarStyle" "$APP/Info.plist" 2>&1 | head -1
```

Expected, in order: `co.tuntun.tapescan`, `TapeScan`, `1.0`, `false`, `Dark`, `arkit`, then a `Does Not Exist` error for `UIStatusBarStyle`.

4. **Shared scheme + entitlements are committed:**

```bash
ls TapeMeasureARPro.xcodeproj/xcshareddata/xcschemes/TapeScan.xcscheme
grep -c "CODE_SIGN_ENTITLEMENTS = Sources/Resources/TapeScan.entitlements" TapeMeasureARPro.xcodeproj/project.pbxproj
git status --short
```

Expected: the scheme path prints; the grep count is ≥ 1; `git status` is clean (everything committed across the 6 task commits).

### Simulator — manual smoke (Debug app)

1. Boot and install:

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; xcrun simctl install booted /tmp/tapescan-verify/Build/Products/Debug-iphonesimulator/TapeScan.app
xcrun simctl launch booted co.tuntun.tapescan -uiPhase main
```

2. In the running app (or via `open -a Simulator`): the home screen icon is labeled **TapeScan**; the app renders dark.
3. Settings tab → "Theme" group shows **Accent color** and (Debug build only) **Brand name**; the Pro upsell card reads **"TapeScan Pro"**.
4. Clear the Brand name field and tap return — it falls back to **TapeScan** (not "TapeMeasure").
5. Measure tab → the floating Precision/Minimal/Pro picker is visible (Debug). Recall from Task 6 Step 4 that the Release binary contains neither "Brand name" nor "HUD style" strings, so both surfaces are provably absent from Release.
6. Relaunch with `xcrun simctl launch booted co.tuntun.tapescan -uiPhase onboarding` (after `xcrun simctl terminate booted co.tuntun.tapescan`): the welcome eyebrow reads **"TAPESCAN AR PRO"**, and the permission step copy starts with **"TapeScan uses your camera…"**. Clean up `/tmp/tapescan-verify` afterwards.

### Device (deferred — owner input required)

Nothing in M1 requires a device. When the owner supplies the Apple Team ID: uncomment `DEVELOPMENT_TEAM` in `project.yml`, set `CODE_SIGNING_ALLOWED`/`CODE_SIGNING_REQUIRED` to `YES`, run `xcodegen generate`, and confirm Xcode resolves automatic signing with the In-App Purchase + Sign in with Apple capabilities from `Sources/Resources/TapeScan.entitlements`. This is tracked as an owner input, not an M1 exit criterion.
