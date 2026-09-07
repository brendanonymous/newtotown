import Foundation

/// The onboarding state machine can be tested without sending mail or creating users.
public protocol OnboardingService: Sendable {
    func currentUserID() async throws -> UUID?
    func sendCode(to email: String) async throws
    func verifyCode(_ code: String, email: String) async throws -> UUID
    func profile(for userID: UUID) async throws -> Profile?
    func save(_ profile: Profile) async throws
    func signOut() async throws
}
