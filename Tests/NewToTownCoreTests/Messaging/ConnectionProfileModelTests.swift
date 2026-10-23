import Foundation
import Testing

@testable import NewToTownCore

@Test @MainActor func connectionProfileRefreshRevokesCachedProfileWhenUnavailable() async {
    let service = MessagingTestService()
    let model = ConnectionProfileModel(conversationID: messagingThread.id, service: service)
    await model.load()
    #expect(model.profile == messagingPeer)
    service.onHistory = { throw MessagingError.unavailable }
    await model.load()
    #expect(model.profile == nil)
    #expect(model.errorMessage == "This profile is no longer available.")
}

@Test @MainActor func connectionProfileRejectsAnotherConversation() async {
    let service = MessagingTestService()
    let model = ConnectionProfileModel(conversationID: UUID(), service: service)
    await model.load()
    #expect(model.profile == nil)
    #expect(model.errorMessage != nil)
}

@Test @MainActor func connectionProfileResetDiscardsLateResponse() async {
    let service = MessagingTestService()
    var continuation: CheckedContinuation<MessagePage, Never>?
    service.onHistory = {
        await withCheckedContinuation { continuation = $0 }
    }
    let model = ConnectionProfileModel(conversationID: messagingThread.id, service: service)
    let load = Task { await model.load() }
    while continuation == nil { await Task.yield() }
    model.reset()
    continuation?.resume(returning: MessagePage(conversation: messagingThread, messages: [], nextCursor: nil))
    await load.value
    #expect(model.profile == nil && !model.isLoading && model.errorMessage == nil)
}
