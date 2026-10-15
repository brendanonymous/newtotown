import Testing
@testable import NewToTownCore

@MainActor private final class TestPersonalInfoService: PersonalInfoService {
    enum Failure: Error { case unavailable }
    var value = PersonalInfo(email: "alex@example.com", phone: nil)
    var fails = false
    var onLoad: (@MainActor () async throws -> PersonalInfo)?

    func load() async throws -> PersonalInfo {
        if let onLoad { return try await onLoad() }
        if fails { throw Failure.unavailable }
        return value
    }
}

@Test func emptyAuthContactValuesRemainMissing() {
    let info = PersonalInfo(email: "  alex@example.com\n", phone: "  ")
    #expect(info.email == "alex@example.com")
    #expect(info.phone == nil)
    #expect(PersonalInfo(email: nil, phone: "").email == nil)
}

@Test @MainActor func failedPersonalInfoRefreshClearsPrivateDataAndCanRetry() async {
    let service = TestPersonalInfoService()
    let model = PersonalInfoModel(service: service)
    await model.load()
    #expect(model.info?.email == "alex@example.com")
    #expect(model.info?.phone == nil)
    service.fails = true
    await model.load()
    #expect(model.info == nil)
    #expect(model.errorMessage != nil)
    #expect(!model.isBusy)
    service.fails = false
    service.value = PersonalInfo(email: "updated@example.com", phone: "+14805550123")
    await model.load()
    #expect(model.info == service.value)
    #expect(model.errorMessage == nil)
}

@Test @MainActor func cancelledPersonalInfoLoadDoesNotPublishContactDetails() async {
    let service = TestPersonalInfoService()
    let model = PersonalInfoModel(service: service)
    let started = AsyncStream<Void>.makeStream()
    var events = started.stream.makeAsyncIterator()
    var response: CheckedContinuation<PersonalInfo, any Error>?
    service.onLoad = {
        try await withCheckedThrowingContinuation {
            response = $0
            started.continuation.yield(())
        }
    }
    let task = Task { await model.load() }
    await events.next()
    task.cancel()
    response?.resume(returning: service.value)
    await task.value
    #expect(model.info == nil)
    #expect(model.errorMessage != nil)
    #expect(!model.isBusy)
    started.continuation.finish()
}

@Test(arguments: [false, true]) @MainActor
func cancelledPersonalInfoRefreshKeepsLoadedContactsAndCanRetry(throwsCancellation: Bool) async {
    let service = TestPersonalInfoService()
    let model = PersonalInfoModel(service: service)
    await model.load()
    let previous = model.info
    let started = AsyncStream<Void>.makeStream()
    var events = started.stream.makeAsyncIterator()
    var response: CheckedContinuation<PersonalInfo, any Error>?
    service.onLoad = {
        try await withCheckedThrowingContinuation {
            response = $0
            started.continuation.yield(())
        }
    }
    let refresh = Task { await model.load() }
    await events.next()
    refresh.cancel()
    if throwsCancellation {
        response?.resume(throwing: CancellationError())
    } else {
        response?.resume(returning: PersonalInfo(email: "discarded@example.com", phone: nil))
    }
    await refresh.value
    #expect(model.info == previous)
    #expect(model.errorMessage == nil)
    #expect(!model.isBusy)
    service.onLoad = nil
    service.value = PersonalInfo(email: "updated@example.com", phone: nil)
    await model.load()
    #expect(model.info == service.value)
    started.continuation.finish()
}
