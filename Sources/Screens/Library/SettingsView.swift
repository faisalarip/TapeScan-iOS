// SettingsView.swift — the reskin surface + live tweak panel (Settings tab).
//
// Ported from the design's `Settings` (support.jsx + the verified HTML
// reference) and extended with the explicitly-requested Theme group so the
// white-label template is *visibly* reskinnable from inside the running app:
//   • Pro upsell card (accent gradient → would route to the paywall).
//   • Measurement: Units (segmented → AppState.unit), Point snapping (toggle),
//     Precision (row showing ±4 mm / ±2 cm derived from the LiDAR flag).
//   • AR Engine: LiDAR depth (toggle → AppState.lidar, re-themes the whole app),
//     Plane detection (segmented, local).
//   • Theme: accent swatch picker (5 options → AppState.accent) + a brand-name
//     field (→ AppState.brand). Mutating either re-themes every screen live.
//
// Everything recomputes live because the controls bind straight to the
// `@Observable` AppState; `Theme(appState)` is rebuilt by the root on change.

import SwiftUI
import StoreKit
import SwiftData

public struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    // Local interactive state for controls that are not global tweaks.
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false
    @State private var isRestoring = false
    @State private var showAuthSheet = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @Environment(\.openURL) private var openURL

    public init() {}

    public var body: some View {
        // Bind directly to the observable app state so segmented/toggle controls
        // mutate the source of truth and the UI re-themes immediately.
        @Bindable var appState = appState

        return ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                title

                ScrollView {
                    VStack(spacing: 18) {
                        if !appState.isPro { proUpsell }
                        measurementGroup(unit: $appState.unit,
                                         snap: $appState.snapEnabled)
                        arEngineGroup
                        themeGroup(accent: appState.accent,
                                   setAccent: { appState.accent = $0 },
                                   brand: $appState.brand)
                        accountGroup
                        purchasesGroup
                        aboutGroup
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .sheet(isPresented: $showAuthSheet) {
            AuthFlowView { showAuthSheet = false }
                .environment(appState)
                .installTheme(Theme(appState))
        }
        .confirmationDialog("Delete account?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete account and synced data", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and everything synced to it. Measurements and rooms on this device are kept.")
        }
        .fullScreenCover(isPresented: $showPaywall) {
            // The Settings card is always a proactive upsell, so the headline must
            // not falsely claim the free quota is spent.
            PaywallView(context: .proactive(freeExportsLeft: appState.freeExportsLeft)) {
                showPaywall = false
            }
            .environment(appState)
            .installTheme(Theme(appState))
        }
    }

    // MARK: - Large title

    private var title: some View {
        HStack {
            Text("Settings")
                .font(Theme.sans(30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Pro upsell

    private var proUpsell: some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.r(12), style: .continuous)
                        .fill(Color.white.opacity(0.2))
                    Icon("cube3d", size: 24, weight: 1.8, color: .white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(appState.brand) Pro")
                        .font(Theme.sans(16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("USDZ + glTF export · unlimited rooms")
                        .font(Theme.sans(12.5))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                Spacer(minLength: 8)

                Text("Upgrade")
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(Color(hex: "#111111"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                    .fill(LinearGradient(
                        colors: [theme.accent.withA(0.9), theme.accent.withA(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to \(appState.brand) Pro")
    }

    // MARK: - Measurement

    private func measurementGroup(unit: Binding<MeasureUnit>,
                                  snap: Binding<Bool>) -> some View {
        DListSection(header: "Measurement") {
            DRow(icon: "ruler2", title: "Units", accessory: {
                IOSSegmented(options: MeasureUnit.allCases,
                             selection: unit) { $0.title }
                    .accessibilityLabel("Units")
            })
            // Real setting: new points weld to existing ones within 2 cm
            // (closes polygons cleanly). Persisted; the AR service reads it.
            DRow(icon: "pin", title: "Point snapping", accessory: {
                IOSToggle(isOn: snap)
                    .accessibilityLabel("Point snapping")
                    .accessibilityValue(snap.wrappedValue ? "On" : "Off")
            })
            // Precision derives from the detected hardware: ±4 mm vs ±2 cm.
            // Read-only status row (precision derives from hardware). No chevron/
            // tap — it isn't a drill-in.
            DRow(icon: "distance",
                 title: "Precision",
                 detail: theme.precisionBadge,
                 last: true)
            .accessibilityLabel("Precision \(theme.precisionBadge)")
        }
    }

    // MARK: - AR Engine

    /// Read-only hardware status — LiDAR is detected (cached by the Measure
    /// screen from the AR service), never user-toggled.
    private var arEngineGroup: some View {
        DListSection(header: "AR Engine") {
            DRow(icon: "lidar",
                 title: "LiDAR depth",
                 subtitle: appState.lidar
                    ? "Active · mesh reconstruction"
                    : "Not available · visual-inertial fallback",
                 last: true, accessory: {
                StatusDot(color: appState.lidar ? Theme.successGreen : Theme.amber)
            })
            .accessibilityLabel("LiDAR depth: \(appState.lidar ? "active" : "not available, visual fallback")")
        }
    }

    // MARK: - Theme (reskin surface)

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

    // MARK: - Account (optional — backup & sync only)

    @ViewBuilder
    private var accountGroup: some View {
        let auth = SupabaseAuthService.shared
        DListSection(header: "Account") {
            if let email = auth.userEmail ?? (auth.userID != nil ? "Signed in" : nil) {
                DRow(icon: "share",
                     title: "Backed up & syncing",
                     subtitle: email, accessory: {
                    StatusDot(color: Theme.successGreen)
                })
                .accessibilityLabel("Signed in as \(email)")
                DRow(icon: "undo", title: "Sign Out",
                     action: { Task { await signOut() } }, accessory: {
                    Chevron()
                })
                .accessibilityLabel("Sign out")
                DRow(icon: "close", title: "Delete Account",
                     subtitle: "Removes your account and synced data",
                     last: true,
                     action: { showDeleteConfirm = true }, accessory: {
                    Chevron()
                })
                .accessibilityLabel("Delete account")
            } else {
                DRow(icon: "share",
                     title: "Back up & sync",
                     subtitle: "Optional — your data stays on this device either way",
                     last: true,
                     action: { showAuthSheet = true }, accessory: {
                    Chevron()
                })
                .accessibilityLabel("Sign in to back up and sync")
            }
        }
    }

    private func signOut() async {
        do {
            try await SupabaseAuthService.shared.signOut()
            appState.signOut()
            // Remove this account's synced data + pull watermark so it can't leak
            // into the next account on a shared device (re-sign-in re-pulls it).
            SyncEngine.purgeLocalSyncState(context: modelContext)
        } catch {
            appState.presentAlert(title: "Sign out didn't complete",
                                  message: error.localizedDescription)
        }
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await SupabaseAuthService.shared.deleteAccount()
            appState.signOut()
            // Purge the now-deleted account's synced rows + pull watermark locally.
            SyncEngine.purgeLocalSyncState(context: modelContext)
            appState.presentAlert(title: "Account deleted",
                                  message: "Your account and its synced data were removed. Anything you saved only on this device stays here.")
        } catch {
            appState.presentAlert(title: "Couldn't delete account",
                                  message: error.localizedDescription)
        }
    }

    // MARK: - Purchases

    private var purchasesGroup: some View {
        DListSection(header: "Purchases") {
            DRow(icon: "download",
                 title: "Restore Purchases",
                 detail: isRestoring ? "…" : nil,
                 action: { Task { await restorePurchases() } }, accessory: {
                Chevron()
            })
            .accessibilityLabel("Restore Purchases")
            DRow(icon: "gear",
                 title: "Manage Subscription",
                 last: true,
                 action: { showManageSubscriptions = true }, accessory: {
                Chevron()
            })
            .accessibilityLabel("Manage Subscription")
        }
    }

    private func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        let result = await StoreKitPurchaseService().restore()
        isRestoring = false
        switch result {
        case .success:
            appState.isPro = true
            appState.presentAlert(title: "Purchases restored",
                                  message: "TapeScan Pro is active on this device.")
        case .cancelled:
            break
        case .failed(let message):
            appState.presentAlert(title: "Restore didn't complete", message: message)
        }
    }

    // MARK: - About

    private var aboutGroup: some View {
        DListSection(header: "About") {
            DRow(icon: "layers", title: "Terms of Use",
                 action: { openURL(LegalLinks.terms) }, accessory: {
                Chevron()
            })
            .accessibilityLabel("Terms of Use")
            DRow(icon: "pin", title: "Privacy Policy",
                 action: { openURL(LegalLinks.privacy) }, accessory: {
                Chevron()
            })
            .accessibilityLabel("Privacy Policy")
            DRow(icon: "gear", title: "Version",
                 detail: Self.versionString,
                 last: true, accessory: {
                EmptyView()
            })
            .accessibilityLabel("Version \(Self.versionString)")
        }
    }

    /// "1.0 (1)" from the bundle — single source for support conversations.
    private static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}

// MARK: - Accent swatch

/// A single tappable accent color swatch with a selected ring + check.
private struct AccentSwatch: View {
    @Environment(\.theme) private var theme
    let option: AccentOption
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(option.color)
                    .frame(width: 26, height: 26)
                if selected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: 32, height: 32)
                    Icon("check", size: 14, weight: 2.6, color: .white)
                }
            }
            .frame(width: 36, height: 36)        // 44pt row height keeps the target tappable
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.name) accent")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Brand field

/// Inline trailing text field bound to `AppState.brand`. Blank input falls back
/// so the wordmark never renders empty.
private struct BrandField: View {
    @Environment(\.theme) private var theme
    @Binding var brand: String
    @FocusState private var focused: Bool

    var body: some View {
        TextField("",
                  text: $brand,
                  prompt: Text(AppState.defaultBrand).foregroundColor(Theme.ink3))
            .font(Theme.sans(14.5, weight: .medium))
            .foregroundStyle(Theme.ink)
            .tint(theme.accent)
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
            .focused($focused)
            .frame(maxWidth: 150)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: theme.r(8), style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(8), style: .continuous)
                    .strokeBorder(focused ? theme.accent.withA(0.8) : Color.white.opacity(0.10),
                                  lineWidth: focused ? 1.5 : 1)
            )
            .onSubmit { normalize() }
            .onChange(of: focused) { _, isFocused in if !isFocused { normalize() } }
            .accessibilityLabel("Brand name")
    }

    /// Collapse all-whitespace input back to the default brand.
    private func normalize() {
        if brand.trimmingCharacters(in: .whitespaces).isEmpty { brand = AppState.defaultBrand }
    }
}

#Preview("Settings · LiDAR + Blue") {
    SettingsView()
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}

#Preview("Settings · Fallback + Violet") {
    let state = AppState()
    state.lidar = false
    state.accent = .violet
    return SettingsView()
        .environment(state)
        .environment(\.theme, Theme(state))
}
