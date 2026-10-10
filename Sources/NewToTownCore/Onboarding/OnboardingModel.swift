import Foundation
import Observation

@MainActor
@Observable
public final class OnboardingModel {
    public enum Step: Equatable {
        case loading, email, code, introduction, profile, saved, restoreFailed
    }

    public private(set) var step: Step = .loading
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?
    public private(set) var email = ""
    public private(set) var resendAvailableAt = Date.distantPast
    public var draft = ProfileDraft()

    private let service: any OnboardingService
    private var userID: UUID?
    private var hasAcceptedAgreement = false

    public var canDeleteAccount: Bool { userID != nil }

    public init(service: any OnboardingService) { self.service = service }

    public func restore() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            guard let id = try await service.currentUserID() else {
                step = .email
                return
            }
            userID = id
            try await loadProfile(for: id)
        } catch {
            step = .restoreFailed
            errorMessage = "We couldn’t load your account. Check your connection and try again."
        }
    }

    public func requestCode(email input: String) async {
        guard !isBusy else { return }
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else {
            errorMessage = "Enter a valid email address."
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await service.sendCode(to: normalized)
            email = normalized
            resendAvailableAt = Date.now.addingTimeInterval(60)
            step = .code
        } catch {
            errorMessage = "We couldn’t send a code. Check your connection or wait a minute before trying again."
        }
    }

    public func resendCode() async {
        guard Date.now >= resendAvailableAt else { return }
        await requestCode(email: email)
    }

    public func changeEmail() {
        guard !isBusy else { return }
        step = .email
        errorMessage = nil
    }

    public func verify(code: String) async {
        guard !isBusy else { return }
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (6...10).contains(code.count), code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            errorMessage = "Enter the numeric code from your email."
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let id = try await service.verifyCode(code, email: email)
            userID = id
            do {
                try await loadProfile(for: id)
            } catch {
                step = .restoreFailed
                errorMessage = "You’re signed in, but we couldn’t load your profile. Try again."
            }
        } catch {
            errorMessage = "That code couldn’t be verified. Check it or request a new one."
        }
    }

    public func saveProfile() async {
        guard !isBusy, step == .profile, hasAcceptedAgreement, let userID else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let profile = try Profile(id: userID, draft: draft)
            try await service.save(profile)
            draft = ProfileDraft(profile: profile)
            step = .saved
        } catch let error as ProfileValidationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Your profile wasn’t saved. Check your connection and try again."
        }
    }

    public func acceptIntroduction() async {
        guard !isBusy, step == .introduction, let userID else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await service.acceptAgreement(for: userID)
            hasAcceptedAgreement = true
            try await loadProfile(for: userID)
        } catch {
            errorMessage = "We couldn’t finish setting up your account. Try again."
        }
    }

    public func editProfile() {
        guard !isBusy, hasAcceptedAgreement else { return }
        errorMessage = nil
        step = .profile
    }

    public func signOut() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await service.signOut()
            clearAccount()
        } catch {
            errorMessage = "Sign out failed. Please try again."
        }
    }

    public func deleteAccount() async {
        guard !isBusy, userID != nil else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await service.deleteAccount()
            clearAccount()
        } catch {
            errorMessage = "We couldn’t confirm account deletion. Try again, or sign out and sign in to check your account."
        }
    }

    private func clearAccount() {
        userID = nil
        hasAcceptedAgreement = false
        draft = ProfileDraft()
        email = ""
        resendAvailableAt = .distantPast
        step = .email
    }

    private func loadProfile(for id: UUID) async throws {
        hasAcceptedAgreement = try await service.hasAcceptedAgreement(for: id)
        guard hasAcceptedAgreement else {
            step = .introduction
            return
        }
        if let profile = try await service.profile(for: id) {
            draft = ProfileDraft(profile: profile)
            step = .saved
        } else {
            draft = ProfileDraft()
            draft.platonicAgreement = true
            step = .profile
        }
    }
}
