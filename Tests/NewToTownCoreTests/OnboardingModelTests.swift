import Foundation
import Testing
@testable import NewToTownCore

@MainActor
private final class TestOnboardingService: OnboardingService {
    enum Failure: Error { case unavailable }
    let id = UUID()
    var signedIn = false
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
    }
    func signOut() async throws { signedIn = false }
}

@Test @MainActor func completesSignupAndRestoresSavedProfile() async {
    let service = TestOnboardingService()
    let model = OnboardingModel(service: service)
    await model.restore()
    #expect(model.step == .email)
    await model.requestCode(email: "  ALEX@example.com ")
    #expect(service.sentEmails == ["alex@example.com"])
    #expect(model.step == .code)
    await model.verify(code: "123456")
    #expect(model.step == .profile)
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
