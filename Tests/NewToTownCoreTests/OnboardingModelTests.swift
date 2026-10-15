import Foundation
import Testing
@testable import NewToTownCore

@MainActor
private final class TestOnboardingService: OnboardingService {
    enum Failure: Error { case unavailable }
    let id = UUID()
    var signedIn = false
    var acceptedAgreement = true
    var failAcceptance = false
    var acceptances = 0
    var storedProfile: Profile?
    var sentEmails: [String] = []
    var failSend = false
    var failVerify = false
    var failLoad = false
    var failSave = false
    var saves = 0
    var failDelete = false
    var deletions = 0

    func currentUserID() async throws -> UUID? { signedIn ? id : nil }
    func sendCode(to email: String) async throws {
        if failSend { throw Failure.unavailable }
        sentEmails.append(email)
    }
    func verifyCode(_ code: String, email: String) async throws -> UUID {
        if failVerify { throw Failure.unavailable }
        signedIn = true
        return id
    }
    func profile(for userID: UUID) async throws -> Profile? {
        if failLoad { throw Failure.unavailable }
        return storedProfile
    }
    func hasAcceptedAgreement(for userID: UUID) async throws -> Bool {
        if failLoad { throw Failure.unavailable }
        return acceptedAgreement
    }
    func acceptAgreement(for userID: UUID) async throws {
        if failAcceptance { throw Failure.unavailable }
        acceptedAgreement = true
        acceptances += 1
    }
    func save(_ profile: Profile) async throws {
        if failSave { throw Failure.unavailable }
        saves += 1
        storedProfile = profile
    }
    func deleteAccount() async throws {
        if failDelete { throw Failure.unavailable }
        deletions += 1
        signedIn = false
        storedProfile = nil
        acceptedAgreement = false
    }
    func signOut() async throws { signedIn = false }
}

@Test @MainActor func completesSignupAndRestoresSavedProfile() async {
    let service = TestOnboardingService()
    let model = OnboardingModel(service: service)
    await model.restore()
    #expect(model.step == .email)
    #expect(!model.isSignedIn)
    await model.requestCode(email: "  ALEX@example.com ")
    #expect(service.sentEmails == ["alex@example.com"])
    #expect(model.step == .code)
    await model.verify(code: "123456")
    #expect(model.step == .profile)
    #expect(model.isSignedIn)
    model.draft = validDraft()
    await model.saveProfile()
    #expect(model.step == .saved)
    #expect(service.storedProfile?.id == service.id)
    let restored = OnboardingModel(service: service)
    await restored.restore()
    #expect(restored.step == .saved)
    #expect(restored.draft.firstName == "Alex")
    await restored.signOut()
    #expect(restored.step == .email)
    #expect(!restored.isSignedIn)
    #expect(restored.draft == ProfileDraft())
}

@Test @MainActor func invalidEmailAndFailedDeliveryDoNotAdvance() async {
    let service = TestOnboardingService()
    let model = OnboardingModel(service: service)
    await model.restore()
    await model.requestCode(email: "invalid")
    #expect(service.sentEmails.isEmpty)
    service.failSend = true
    await model.requestCode(email: "alex@example.com")
    #expect(model.step == .email)
    #expect(model.errorMessage != nil)
    #expect(!model.isBusy)
}

@Test @MainActor func failedVerificationStaysOnCodeStep() async {
    let service = TestOnboardingService()
    let model = OnboardingModel(service: service)
    await model.requestCode(email: "alex@example.com")
    service.failVerify = true
    await model.verify(code: "123456")
    #expect(model.step == .code)
    #expect(!service.signedIn)
    await model.resendCode()
    #expect(service.sentEmails.count == 1)
}

@Test @MainActor func loadFailureDoesNotOverwriteExistingProfile() async {
    let service = TestOnboardingService()
    service.signedIn = true
    service.failLoad = true
    let model = OnboardingModel(service: service)
    await model.restore()
    #expect(model.step == .restoreFailed)
    #expect(service.saves == 0)
    service.failLoad = false
    await model.restore()
    #expect(model.step == .profile)
}

@Test @MainActor func invalidAndFailedSavesPreserveDraft() async {
    let service = TestOnboardingService()
    service.signedIn = true
    let model = OnboardingModel(service: service)
    await model.restore()
    await model.saveProfile()
    #expect(service.saves == 0)
    model.draft = validDraft()
    service.failSave = true
    await model.saveProfile()
    #expect(model.step == .profile)
    #expect(model.draft == validDraft())
    #expect(model.errorMessage != nil)
}

@Test @MainActor func deletionClearsPrivateStateAndAllowsNewSignup() async throws {
    let service = TestOnboardingService()
    service.signedIn = true
    service.storedProfile = try Profile(id: service.id, draft: validDraft())
    let model = OnboardingModel(service: service)
    await model.restore()
    await model.deleteAccount()
    #expect(service.deletions == 1)
    #expect(!model.isSignedIn)
    #expect(!service.signedIn)
    #expect(service.storedProfile == nil)
    #expect(model.step == .email)
    #expect(model.draft == ProfileDraft())
    #expect(model.email.isEmpty)
    #expect(model.resendAvailableAt == .distantPast)
    #expect(model.errorMessage == nil)
    #expect(!model.isBusy)
    await model.deleteAccount()
    #expect(service.deletions == 1)
    await model.requestCode(email: "new@example.com")
    #expect(model.step == .code)
}

@Test @MainActor func failedDeletionKeepsProfileAndCanBeRetried() async throws {
    let service = TestOnboardingService()
    service.signedIn = true
    service.storedProfile = try Profile(id: service.id, draft: validDraft())
    let model = OnboardingModel(service: service)
    await model.restore()
    let originalDraft = model.draft
    service.failDelete = true
    await model.deleteAccount()
    #expect(model.step == .saved)
    #expect(model.draft == originalDraft)
    #expect(model.errorMessage != nil)
    #expect(!model.isBusy)
    #expect(service.deletions == 0)
    service.failDelete = false
    await model.deleteAccount()
    #expect(model.step == .email)
    #expect(service.deletions == 1)
}

@Test @MainActor func firstSignupRequiresPersistedAgreementBeforeProfileAndNeverRepeatsIt() async {
    let service = TestOnboardingService()
    service.acceptedAgreement = false
    let model = OnboardingModel(service: service)
    await model.requestCode(email: "alex@example.com")
    await model.verify(code: "123456")
    #expect(model.step == .introduction)
    model.draft = validDraft()
    await model.saveProfile()
    #expect(service.saves == 0)
    service.failAcceptance = true
    await model.acceptIntroduction()
    #expect(model.step == .introduction)
    #expect(model.errorMessage != nil)
    service.failAcceptance = false
    await model.acceptIntroduction()
    #expect(model.step == .profile)
    #expect(model.draft.platonicAgreement)
    #expect(service.acceptances == 1)
    // Resume an accepted signup even if no profile was saved yet.
    let resumed = OnboardingModel(service: service)
    await resumed.restore()
    #expect(resumed.step == .profile)
    #expect(service.acceptances == 1)
    resumed.draft = validDraft()
    await resumed.saveProfile()
    resumed.editProfile()
    #expect(resumed.step == .profile)
    await resumed.signOut()
    await resumed.requestCode(email: "alex@example.com")
    await resumed.verify(code: "123456")
    #expect(resumed.step == .saved)
    #expect(service.acceptances == 1)
}

@Test @MainActor func pendingIntroductionSurvivesRestartWithoutInventingConsent() async {
    let service = TestOnboardingService()
    service.signedIn = true
    service.acceptedAgreement = false
    let model = OnboardingModel(service: service)
    await model.restore()
    #expect(model.step == .introduction)
    #expect(service.acceptances == 0)
    await model.signOut()
    #expect(model.step == .email)
}

@Test @MainActor func existingPilotAccountAcceptsOnceWithoutChangingSavedProfile() async throws {
    let service = TestOnboardingService()
    service.signedIn = true
    service.acceptedAgreement = false
    service.storedProfile = try Profile(id: service.id, draft: validDraft())
    let original = service.storedProfile
    let model = OnboardingModel(service: service)
    await model.restore()
    #expect(model.step == .introduction)
    await model.acceptIntroduction()
    #expect(model.step == .saved)
    #expect(service.storedProfile == original)
    #expect(service.saves == 0)
    await model.restore()
    #expect(model.step == .saved)
    #expect(service.acceptances == 1)
}
