import Foundation
import Testing

@testable import NewToTownCore

@Test @MainActor func inboxMergesMovingRowsAndRefreshReplacesOldPages() async {
    let service = MessagingTestService()
    let second = Conversation(
        id: UUID(), participant: messagingPeer, createdAt: messagingTime,
        lastActivityAt: messagingTime, lastMessage: nil)
    let cursor = MessageCursor(time: messagingTime, id: messagingThread.id)
    service.listPages = [
        ConversationPage(conversations: [messagingThread], nextCursor: cursor),
        ConversationPage(conversations: [messagingThread, second], nextCursor: nil),
        ConversationPage(conversations: [second], nextCursor: nil),
    ]
    let model = ConversationListModel(service: service)
    await model.load()
    await model.load(older: true)
    #expect(model.conversations.count == 2)
    await model.load()
    #expect(model.conversations.map(\.id) == [second.id])
}

@Test @MainActor func inboxFailureClearsPrivatePreviewsAndCanRetry() async {
    let service = MessagingTestService()
    let model = ConversationListModel(service: service)
    await model.load()
    service.onList = { throw MessagingError.signedOut }
    await model.load()
    #expect(model.conversations.isEmpty && model.errorMessage != nil && !model.hasLoaded)
    service.onList = nil
    await model.load()
    #expect(model.conversations.count == 1 && model.errorMessage == nil)
}

@Test @MainActor func resetDiscardsLateInboxForPreviousAccount() async {
    let service = MessagingTestService()
    let model = ConversationListModel(service: service)
    let started = AsyncStream<Void>.makeStream()
    var events = started.stream.makeAsyncIterator()
    var response: CheckedContinuation<ConversationPage, any Error>?
    service.onList = {
        try await withCheckedThrowingContinuation {
            response = $0
            started.continuation.yield(())
        }
    }
    let load = Task { await model.load() }
    await events.next()
    model.reset()
    response?.resume(returning: ConversationPage(conversations: [messagingThread], nextCursor: nil))
    await load.value
    #expect(model.conversations.isEmpty && !model.hasLoaded && !model.isLoading)
    started.continuation.finish()
}

@Test @MainActor func reportedPeerCannotReturnInLateInboxResponseAndOtherThreadsRemain() async {
    let service = MessagingTestService()
    let otherPeer = DiscoveryProfile(
        id: UUID(), firstName: "Sam", jobTitle: "Teacher", goal: "Go hiking.",
        city: "Scottsdale", photoURL: messagingPeer.photoURL)
    let other = Conversation(
        id: UUID(), participant: otherPeer, createdAt: messagingTime,
        lastActivityAt: messagingTime, lastMessage: nil)
    let page = ConversationPage(
        conversations: [messagingThread, other],
        nextCursor: MessageCursor(time: messagingTime, id: messagingThread.id))
    service.listPages = [page]
    let model = ConversationListModel(service: service)
    await model.load()
    var response: CheckedContinuation<ConversationPage, Never>?
    service.onList = { await withCheckedContinuation { response = $0 } }
    let refresh = Task { await model.load() }
    while response == nil { await Task.yield() }
    model.excludeProfiles([messagingPeer.id])
    #expect(model.conversations.map(\.id) == [other.id])
    response?.resume(returning: page)
    await refresh.value
    #expect(model.conversations.map(\.id) == [other.id] && model.nextCursor == nil)
}
