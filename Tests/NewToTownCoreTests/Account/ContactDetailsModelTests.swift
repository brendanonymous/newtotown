import Foundation
import Testing

@testable import NewToTownCore

@MainActor private final class ContactStub: ContactDetailsService {
    var requested: [ContactDestination] = []
    var resends = 0
    var confirmedInfo = PersonalInfo(email: nil, phone: nil)
    func confirmedEmail() throws -> PersonalInfo {
        if let failure { throw failure }
        return confirmedInfo
    }
    var failure: ContactDetailsError?
    var onVerify: (@MainActor (ContactDestination) async throws -> PersonalInfo)?
    func requestVerification(for destination: ContactDestination) throws {
        if let failure { throw failure }
        requested.append(destination)
    }
    func resendVerification(for destination: ContactDestination) { resends += 1 }
    func verify(_ destination: ContactDestination, code: String) async throws -> PersonalInfo {
        if let onVerify { return try await onVerify(destination) }
        if let failure { throw failure }
        return PersonalInfo(
            email: destination.kind == .email ? destination.value : nil,
            phone: destination.kind == .phone ? destination.value : nil)
    }
}

@Test func contactDestinationsValidateAndNormalize() {
    #expect(ContactDestination(kind: .email, input: " Alex@Example.com \n")?.value == "alex@example.com")
    #expect(ContactDestination(kind: .email, input: "not an email") == nil)
    #expect(ContactDestination(kind: .phone, input: "480-555-0123")?.value == "+14805550123")
    #expect(ContactDestination(kind: .phone, input: "123") == nil)
    #expect(
        ContactDestination(kind: .phone, input: "4805550123")?.matches(
            PersonalInfo(email: nil, phone: "14805550123")) == true)
}

@Test @MainActor func contactRequestValidatesInputAndEnforcesResendCooldown() async {
    let service = ContactStub()
    var now = Date(timeIntervalSince1970: 1000)
    let model = ContactDetailsModel(kind: .email, service: service, now: { now })
    model.input = "invalid"
    await model.requestCode()
    #expect(service.requested.isEmpty)
    #expect(model.errorMessage != nil)
    model.input = "alex@example.com"
    await model.requestCode()
    #expect(model.destination?.value == "alex@example.com")
    #expect(!model.canResend)
    await model.resend()
    #expect(service.resends == 0)
    now.addTimeInterval(60)
    #expect(model.canResend)
    await model.resend()
    #expect(service.resends == 1)
    #expect(!model.canResend)
}

@Test @MainActor func contactVerificationPreservesDraftOnFailureAndSupportsRetry() async {
    let service = ContactStub()
    let model = ContactDetailsModel(kind: .phone, service: service)
    model.input = "4805550123"
    await model.requestCode()
    model.code = "１２３４５６"
    #expect(await model.verify() == false)
    service.failure = .invalidCode
    model.code = "123456"
    #expect(await model.verify() == false)
    #expect(model.destination?.value == "+14805550123")
    #expect(model.code == "123456")
    #expect(model.errorMessage != nil)
    service.failure = nil
    #expect(await model.verify())
    #expect(model.errorMessage == nil)
}

@Test @MainActor func contactResetDiscardsLateVerification() async {
    let service = ContactStub()
    let model = ContactDetailsModel(kind: .email, service: service)
    model.input = "alex@example.com"
    await model.requestCode()
    model.code = "123456"
    let started = AsyncStream<Void>.makeStream()
    var events = started.stream.makeAsyncIterator()
    var pending: CheckedContinuation<PersonalInfo, any Error>?
    service.onVerify = { _ in
        try await withCheckedThrowingContinuation {
            pending = $0
            started.continuation.yield(())
        }
    }
    let verification = Task { await model.verify() }
    await events.next()
    model.reset()
    pending?.resume(returning: PersonalInfo(email: "alex@example.com", phone: nil))
    #expect(await verification.value == false)
    #expect(model.destination == nil && model.code.isEmpty && !model.isBusy)
    started.continuation.finish()
}

@Test @MainActor func contactVerificationRejectsMismatchedUserDetails() async {
    let service = ContactStub()
    let model = ContactDetailsModel(kind: .email, service: service)
    model.input = "alex@example.com"
    await model.requestCode()
    model.code = "123456"
    service.onVerify = { _ in PersonalInfo(email: "other@example.com", phone: nil) }
    #expect(await model.verify() == false)
}

@Test @MainActor func browserVerificationRequiresThePendingEmailAndSupportsRetry() async {
    let service = ContactStub()
    let model = ContactDetailsModel(kind: .email, service: service)
    model.input = "alex@example.com"
    await model.requestCode()
    service.confirmedInfo = PersonalInfo(email: "other@example.com", phone: nil)
    #expect(await model.checkEmailVerification() == false)
    #expect(model.destination?.value == "alex@example.com")
    service.confirmedInfo = PersonalInfo(email: "alex@example.com", phone: nil)
    #expect(await model.checkEmailVerification())
    model.reset()
    #expect(await model.checkEmailVerification() == false)
}
