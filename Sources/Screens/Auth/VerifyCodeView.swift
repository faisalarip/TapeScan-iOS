// VerifyCodeView.swift — email OTP step. Ported 1:1 from auth.jsx `VerifyCode`
// (and the verified HTML build).
//
// Layout (vertically centered):
//   • Accent-soft rounded icon tile ("share" glyph).
//   • "Verify your email" title + "We sent a 6-digit code to <email>" copy.
//   • Six OTP boxes (46×56). The active box shows a blinking accent caret; filled
//     boxes brighten their border. The source seed is "4 8 2 1 _ _" with the 5th
//     box focused — we honor that as the initial state, then accept live input.
//   • "Resend in 0:24" countdown that ticks down to a tappable "Resend" link.
//   • "Verify & Continue" CTA → completes auth in AppState.
//
// The whole OTP row is backed by one hidden `TextField` (numeric keypad). Tapping
// any box focuses it; typing fills boxes left→right; delete clears the last digit.

import SwiftUI

/// Email verification screen with a 6-digit one-time-code entry and resend timer.
/// On "Verify & Continue" it calls `appState.completeAuth()`, advancing the flow
/// out of the `.auth` phase (source flow: verify → welcome/onboarding).
public struct VerifyCodeView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    private static let codeLength = 6

    /// Destination address shown in the body copy.
    private let email: String
    /// Real auth backend.
    private let auth: any AuthService
    /// Verified successfully — the parent dismisses the auth flow.
    private let onVerified: () -> Void

    @State private var code: String = ""
    @State private var isWorking = false
    @FocusState private var fieldFocused: Bool

    /// Seconds remaining before "Resend" becomes tappable.
    @State private var secondsRemaining = 24
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(email: String,
                auth: any AuthService,
                onVerified: @escaping () -> Void = {}) {
        self.email = email
        self.auth = auth
        self.onVerified = onVerified
    }

    @MainActor
    public init(email: String, onVerified: @escaping () -> Void = {}) {
        self.init(email: email, auth: SupabaseAuthService.shared, onVerified: onVerified)
    }

    public var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
                footer
            }
        }
        .onAppear { fieldFocused = true }
        .onReceive(ticker) { _ in
            if secondsRemaining > 0 { secondsRemaining -= 1 }
        }
    }

    // MARK: - Centered content

    private var content: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.r(18), style: .continuous)
                    .fill(theme.accentSoft)
                    .frame(width: 64, height: 64)
                Icon("share", size: 30, weight: 1.8, color: theme.accent)
            }
            .padding(.bottom, 26)

            Text("Verify your email")
                .font(Theme.sans(25, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.ink)

            verifyCopy
                .font(Theme.sans(14.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 10)

            otpRow
                .padding(.top, 30)

            resendRow
                .padding(.top, 26)
        }
        .padding(.horizontal, 30)
    }

    private var verifyCopy: Text {
        Text("We sent a 6-digit code to\n")
            .foregroundColor(Theme.ink2)
        + Text(email)
            .font(Theme.sans(14.5, weight: .semibold))
            .foregroundColor(Theme.ink)
    }

    // MARK: - OTP boxes

    private var otpRow: some View {
        ZStack {
            // Hidden capture field — drives the visible boxes.
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($fieldFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: code) { _, newValue in
                    // Keep digits only, clamp to length.
                    let digits = String(newValue.filter(\.isNumber).prefix(Self.codeLength))
                    if digits != newValue { code = digits }
                }
                .accessibilityLabel("Verification code")

            HStack(spacing: 9) {
                ForEach(0..<Self.codeLength, id: \.self) { index in
                    otpBox(index)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { fieldFocused = true }
        }
    }

    @ViewBuilder
    private func otpBox(_ index: Int) -> some View {
        let digit = digit(at: index)
        let isActive = fieldFocused && index == code.count && code.count < Self.codeLength
        let filled = digit != nil

        ZStack {
            RoundedRectangle(cornerRadius: theme.r(13), style: .continuous)
                .fill(Color.white.opacity(0.05))
            RoundedRectangle(cornerRadius: theme.r(13), style: .continuous)
                .strokeBorder(
                    isActive ? theme.accent
                             : Color.white.opacity(filled ? 0.25 : 0.12),
                    lineWidth: isActive ? 1.5 : 1)

            if let digit {
                Text(String(digit))
                    .font(Theme.mono(24, weight: .bold))
                    .foregroundStyle(Theme.ink)
            } else if isActive {
                BlinkingCaret(color: theme.accent, height: 26)
            }
        }
        .frame(width: 46, height: 56)
        .accessibilityHidden(true)
    }

    private func digit(at index: Int) -> Character? {
        guard index < code.count else { return nil }
        return code[code.index(code.startIndex, offsetBy: index)]
    }

    // MARK: - Resend

    @ViewBuilder
    private var resendRow: some View {
        if secondsRemaining > 0 {
            (Text("Didn't get it? ").foregroundColor(Theme.ink3)
             + Text("Resend in \(timeString)")
                .foregroundColor(theme.accent)
                .fontWeight(.semibold))
                .font(Theme.sans(13.5))
        } else {
            HStack(spacing: 4) {
                Text("Didn't get it?")
                    .foregroundStyle(Theme.ink3)
                Button("Resend") { resend() }
                    .foregroundStyle(theme.accent)
                    .fontWeight(.semibold)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Resend code")
            }
            .font(Theme.sans(13.5))
        }
    }

    /// Actually re-sends the one-time code, then restarts the countdown.
    private func resend() {
        guard !isWorking else { return }
        Task {
            do {
                try await auth.sendEmailOTP(to: email)
                secondsRemaining = 24
            } catch {
                appState.presentAlert(title: "Couldn't resend the code",
                                      message: error.localizedDescription)
            }
        }
    }

    /// `m:ss` formatting (source shows "0:24").
    private var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Footer CTA

    private var footer: some View {
        PrimaryButton(title: isWorking ? "Verifying…" : "Verify & Continue") {
            verify()
        }
        .accessibilityLabel("Verify and continue")
        .disabled(isWorking || code.count < Self.codeLength)
        .opacity(code.count < Self.codeLength ? 0.5 : 1)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 36)
    }

    /// Verifies the code against the real backend; success advances the flow.
    private func verify() {
        guard !isWorking, code.count == Self.codeLength else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await auth.verifyEmailOTP(email: email, code: code)
                appState.completeAuth()
                onVerified()
            } catch {
                appState.presentAlert(title: "That code didn't work",
                                      message: error.localizedDescription)
                code = ""
            }
        }
    }
}

// MARK: - Blinking caret

/// 1.5pt accent caret that hard-blinks (steps) on a 1s cycle, matching the
/// source `tmBlink 1s steps(1) infinite` animation used in the active OTP box.
private struct BlinkingCaret: View {
    let color: Color
    let height: CGFloat
    @State private var visible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

#Preview {
    VerifyCodeView(email: "you@studio.co")
        .environment(AppState())
        .environment(\.theme, Theme(accent: AccentOption.blue.color))
}
