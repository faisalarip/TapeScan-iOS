// GoogleSignInCoordinator.swift — native Google Sign-In flow (M7).
//
// Presents the GoogleSignIn-iOS sheet and returns the Google identity token +
// access token for Supabase's signInWithIdToken exchange (provider: .google).
// The iOS OAuth client id is read from Info.plist `GIDClientID`, and the
// reversed-client-id URL scheme is registered in CFBundleURLTypes.
//
// iOS native Google sign-in does NOT pass a nonce — the Supabase Google provider
// must have "Skip nonce check" enabled and the iOS client id listed under
// "Client IDs".

import GoogleSignIn
import UIKit

@MainActor
enum GoogleSignInCoordinator {

    /// Presents the system Google Sign-In flow. Returns the ID + access tokens.
    /// Throws `CancellationError` if the user dismisses (so callers can stay silent).
    static func signIn() async throws -> (idToken: String, accessToken: String) {
        guard let presenter = topViewController() else {
            throw AuthError.failed("No view controller available to present Google Sign-In.")
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.failed("Google did not return an ID token.")
            }
            return (idToken, result.user.accessToken.tokenString)
        } catch let error as GIDSignInError where error.code == .canceled {
            throw CancellationError()
        }
    }

    /// The top-most presented view controller to anchor the sign-in sheet.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
