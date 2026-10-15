import Foundation

/// The onboarding state machine can be tested without sending mail or creating users.
public protocol OnboardingService: Sendable {
    func currentUserID() async throws -> UUID?
    func sendCode(to email: String) async throws
    func verifyCode(_ code: String, email: String) async throws -> UUID
    func profile(for userID: UUID) async throws -> Profile?
    func hasAcceptedAgreement(for userID: UUID) async throws -> Bool
    func acceptAgreement(for userID: UUID) async throws
    func save(_ profile: Profile) async throws
    /// Deletes the authenticated account, then clears this device’s session.
    func deleteAccount() async throws
    func signOut() async throws
}
