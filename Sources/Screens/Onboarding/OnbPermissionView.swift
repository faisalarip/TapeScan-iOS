// OnbPermissionView.swift — onboarding step 2 · CAMERA & AR PERMISSION PRIME.
//
// Ported 1:1 from onboarding.jsx `OnbPermission`:
//   • Centered 132×132 scanner glyph with a LiDAR success badge.
//   • Title "Camera & AR access" + privacy-forward body copy.
//   • "Frames never leave your device" reassurance pill (green check).
//   • Footer: paging dots (active 1) + "Allow Camera Access" CTA + "Not now".
//
// This is a permission *prime* (App Store best practice): both the CTA and the
// "Not now" affordance advance the flow — the real `AVCaptureDevice` /
// `ARSession` request is fired by the AR seam later, not here.

import SwiftUI
import AVFoundation

/// Onboarding permission step. The CTA fires the REAL system camera prompt
/// (`AVCaptureDevice.requestAccess`); denial shows a recovery path into the
/// system Settings. `onContinue` advances the flow to the calibrate step.
struct OnbPermissionView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var onContinue: () -> Void = {}

    /// Set after the user denies the system prompt (or arrives pre-denied).
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
                footer
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Returning from Settings with camera now enabled → advance automatically
            // instead of stranding the user on the "access is off" recovery screen.
            guard phase == .active, permissionDenied,
                  AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
            onContinue()
        }
    }

    // MARK: - Centered content

    private var content: some View {
        VStack(spacing: 0) {
            glyph
                .padding(.bottom, 34)

            Text("Camera & AR access")
                .font(Theme.sans(25, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text("\(appState.brand) uses your camera to detect surfaces and place measurement points. LiDAR is used automatically when your device supports it.")
                .font(Theme.sans(15))
                .lineSpacing(15 * 0.5)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, 12)

            // privacy reassurance pill
            HStack(spacing: 8) {
                Icon("check", size: 15, weight: 2.4, color: Theme.successGreen)
                Text("Frames never leave your device")
                    .font(Theme.sans(12.5))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.top, 20)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 30)
    }

    /// 132×132 concentric scanner glyph with a LiDAR success badge top-right.
    private var glyph: some View {
        ZStack {
            // outer ring
            Circle()
                .fill(theme.accent.withA(0.12))
                .overlay(Circle().strokeBorder(theme.accent.withA(0.35), lineWidth: 1))
                .frame(width: 132, height: 132)

            // inner disc (inset 22 → 88) + scan icon
            Circle()
                .fill(theme.accent.withA(0.2))
                .frame(width: 88, height: 88)
                .overlay(Icon("scan", size: 48, weight: 1.6, color: theme.accent))

            // LiDAR success badge — top-right, offset (6,6) inside the 132 box
            ZStack {
                Circle()
                    .fill(Theme.screenBG)
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(Theme.successGreen.withA(0.9))
                    .frame(width: 28, height: 28)
                    .overlay(Icon("lidar", size: 17, weight: 1.8, color: Theme.screenBG))
            }
            // center of the 34 badge sits 6+17 from each edge → (132/2 - 23) from center
            .offset(x: 132 / 2 - 6 - 17, y: -(132 / 2 - 6 - 17))
        }
        .frame(width: 132, height: 132)
        .accessibilityHidden(true)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            OnbDots(count: 3, active: 1)

            if permissionDenied {
                Text("Camera access is off. TapeScan can't measure without it — you can enable it in Settings.")
                    .font(Theme.sans(12.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 8)

                PrimaryButton(title: "Open Settings", icon: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .padding(.top, 2)
                .accessibilityLabel("Open Settings")
            } else {
                PrimaryButton(title: "Allow Camera Access", icon: "scan") {
                    requestCameraAccess()
                }
                .padding(.top, 6)
                .accessibilityLabel("Allow camera access")
            }

            Button(action: onContinue) {
                Text("Not now")
                    .font(Theme.sans(14, weight: .medium))
                    .foregroundStyle(Theme.ink3)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)        // 44pt min tap target
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Not now")
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 38)
    }

    /// Fires the system camera prompt. Pre-authorized users skip straight
    /// through; a fresh denial (or a pre-existing one) flips to recovery mode.
    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            onContinue()
        case .denied, .restricted:
            permissionDenied = true
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    onContinue()
                } else {
                    permissionDenied = true
                }
            }
        @unknown default:
            onContinue()
        }
    }
}

#Preview {
    OnbPermissionView()
        .environment(AppState())
        .installTheme(Theme(accent: AccentOption.blue.color))
}
