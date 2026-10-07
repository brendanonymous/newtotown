import Foundation
import NewToTownCore
import Supabase

public final class SupabaseOnboardingService: OnboardingService {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    public func currentUserID() async throws -> UUID? {
        do {
            return try await client.auth.session.user.id
        } catch AuthError.sessionMissing {
            return nil
        }
    }

    public func sendCode(to email: String) async throws {
        try await client.auth.signInWithOTP(email: email, shouldCreateUser: true)
    }

    public func verifyCode(_ code: String, email: String) async throws -> UUID {
        try await client.auth.verifyOTP(email: email, token: code, type: .email)
        return try await client.auth.session.user.id
    }

    public func profile(for userID: UUID) async throws -> Profile? {
        let profiles: [Profile] = try await client.from("profiles")
            .select("id,first_name,job_title,goal,date_of_birth,city,platonic_agreement")
            .eq("id", value: userID).limit(1).execute().value
        return profiles.first
    }

    public func save(_ profile: Profile) async throws {
        try await client.from("profiles").upsert(profile, onConflict: "id").execute()
    }

    public func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")
        // signOut clears Keychain before its network call. The account is gone,
        // so an offline/invalid-token logout response must not report deletion failure.
        try? await client.auth.signOut(scope: .local)
    }

    public func signOut() async throws {
        do {
            try await client.auth.signOut(scope: .local)
        } catch {
            // The SDK clears local credentials before contacting the server.
            // An offline revocation failure must not leave private details on screen.
            if client.auth.currentSession != nil { throw error }
        }
    }
}
