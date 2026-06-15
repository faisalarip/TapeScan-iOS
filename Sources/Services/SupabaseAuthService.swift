// SupabaseAuthService.swift — production auth via supabase-swift (M7).
//
// Apple: native ASAuthorization identity token + nonce → signInWithIdToken.
// Google: native GoogleSignIn ID token → signInWithIdToken (provider .google).
// Email: passwordless one-time codes. Account
// deletion calls the SECURITY DEFINER delete_user() RPC (cascades wipe the
// user's rows), satisfying Guideline 5.1.1(v).

import Foundation
import Observation
import Supabase

@MainActor
@Observable
public final class SupabaseAuthService: AuthService {

    public private(set) var userID: UUID?
    public private(set) var userEmail: String?

    @ObservationIgnored private let client: SupabaseClient?

    /// The shared instance — auth state must be consistent across Settings,
    /// the sign-in sheet, and the sync engine.
    public static let shared = SupabaseAuthService()

    private init() {
        client = SupabaseConfig.isConfigured
            ? SupabaseClient(supabaseURL: SupabaseConfig.url,
                             supabaseKey: SupabaseConfig.anonKey)
            : nil
    }

    /// The database client for sync (nil until configured / implies guest OK).
    public var database: SupabaseClient? { client }

    public func loadSession() async {
        guard let client else { return }
        if let session = try? await client.auth.session {
            apply(session.user)
        }
    }

    public func signInWithApple(idToken: String, nonce: String) async throws {
        guard let client else { throw AuthError.notConfigured }
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
            apply(session.user)
        } catch {
            throw AuthError.failed(error.localizedDescription)
        }
    }

    public func signInWithGoogle(idToken: String, accessToken: String) async throws {
        guard let client else { throw AuthError.notConfigured }
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken))
            apply(session.user)
        } catch {
            throw AuthError.failed(error.localizedDescription)
        }
    }

    public func sendEmailOTP(to email: String) async throws {
        guard let client else { throw AuthError.notConfigured }
        do {
            try await client.auth.signInWithOTP(email: email)
        } catch {
            throw AuthError.failed(error.localizedDescription)
        }
    }

    public func verifyEmailOTP(email: String, code: String) async throws {
        guard let client else { throw AuthError.notConfigured }
        do {
            let response = try await client.auth.verifyOTP(email: email, token: code, type: .email)
            apply(response.user)
        } catch {
            throw AuthError.failed(error.localizedDescription)
        }
    }

    public func signOut() async throws {
        guard let client else { throw AuthError.notConfigured }
        do {
            try await client.auth.signOut()
        } catch {
            throw AuthError.failed(error.localizedDescription)
        }
        userID = nil
        userEmail = nil
    }

    public func deleteAccount() async throws {
        guard let client else { throw AuthError.notConfigured }
        do {
            try await client.rpc("delete_user").execute()
            try? await client.auth.signOut()
        } catch {
            throw AuthError.failed(error.localizedDescription)
        }
        userID = nil
        userEmail = nil
    }

    private func apply(_ user: User?) {
        userID = user?.id
        userEmail = user?.email
    }
}
