// AuthService.swift — optional-accounts seam (M7).
//
// Accounts NEVER gate app use — they exist for backup/sync. The protocol
// keeps views testable; SupabaseAuthService is production. Passwordless by
// design: Sign in with Apple, Google OAuth, or email one-time codes.

import Foundation
import Observation

public enum AuthError: LocalizedError {
    case notConfigured
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sync isn't configured in this build yet."
        case .failed(let message):
            return message
        }
    }
}

@MainActor
public protocol AuthService: AnyObject, Observable {
    /// Signed-in user id; nil = guest (the default, fully functional state).
    var userID: UUID? { get }
    var userEmail: String? { get }

    /// Restore any persisted session (call at launch).
    func loadSession() async

    func signInWithApple(idToken: String, nonce: String) async throws
    func signInWithGoogle() async throws
    func sendEmailOTP(to email: String) async throws
    func verifyEmailOTP(email: String, code: String) async throws
    func signOut() async throws
    /// Server-side account deletion (Guideline 5.1.1(v)) + local sign-out.
    /// Local measurements/rooms stay on device.
    func deleteAccount() async throws
}
