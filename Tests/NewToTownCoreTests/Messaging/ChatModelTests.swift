import Foundation
import Testing

@testable import NewToTownCore

@Test func messageValidationCountsScalarsRatherThanVisibleGraphemes() {
    #expect(MessageText.isValid(String(repeating: "😀", count: 500)))
    #expect(!MessageText.isValid(String(repeating: "😀", count: 501)))
    #expect(MessageText.isValid("  Hello\nthere  "))
    #expect(!MessageText.isValid("\t\n\u{FEFF}\u{00A0}"))
    #expect(!MessageText.isValid("Hello\0"))
    #expect(MessageText.date(messagingTime) != nil)
}

@Test func messageWhitespaceCleanupPreservesWordsAndSingleLineBreaks() {
    let examples = [
        ("  Coffee   on\t\tSaturday?  ", "Coffee on Saturday?"),
        ("Hello \n \n\n there", "Hello\nthere"),
        ("First\r\n\r\nsecond\rthird", "First\nsecond\nthird"),
        ("Café\u{00A0}\u{2003}at 6:30? 👋", "Café at 6:30? 👋"),
        ("\n \t\r\n", ""),
        ("One space\none newline", "One space\none newline"),
    ]
    for (input, expected) in examples {
        let cleaned = MessageText.normalizedWhitespace(input)
        #expect(cleaned == expected)
        #expect(MessageText.normalizedWhitespace(cleaned) == cleaned)
    }
}

@Test @MainActor func historyPagesPreserveCursorPrecisionAndDeduplicateMessages() async {
    let service = MessagingTestService()
    let newer = ChatMessage(
        id: UUID(), conversationID: messagingThread.id, senderID: messagingPeer.id,
        clientMessageID: UUID(), body: "Newer", createdAt: "2026-10-17T23:01:00.000002Z")
    let older = ChatMessage(
        id: UUID(), conversationID: messagingThread.id, senderID: messagingOwner,
        clientMessageID: UUID(), body: "Older", createdAt: messagingTime)
    let cursor = MessageCursor(time: messagingTime, id: newer.id)
    service.historyPages = [
        MessagePage(conversation: messagingThread, messages: [newer], nextCursor: cursor),
        MessagePage(conversation: messagingThread, messages: [newer, older], nextCursor: nil),
    ]
    let model = ChatModel(
        accountID: messagingOwner, target: .peer(messagingPeer.id), messagingService: service)
    await model.load()
    await model.load(older: true)
    #expect(service.historyCursors.count == 2)
    #expect(service.historyCursors[1] == cursor)
    #expect(model.messages.map(\.body) == ["Older", "Newer"])
    #expect(model.nextCursor == nil)
}

@Test @MainActor func draftCapsTypingAndPastingButStillAllowsEditingAndSending() async {
    let service = MessagingTestService()
    let model = ChatModel(
        accountID: messagingOwner, target: .peer(messagingPeer.id), messagingService: service)
    await model.load()
    let full = String(repeating: "a", count: MessageText.maximumLength)
    model.draft = full
    model.draft += "b"
    #expect(!model.canSend)
    model.limitDraft()
    #expect(model.draft == full && model.canSend)
    model.draft.removeLast()
    model.draft += "c"
    #expect(model.draft == String(full.dropLast()) + "c")
    model.draft = String(repeating: "x", count: 700)
    model.limitDraft()
    #expect(model.draft == String(repeating: "x", count: 500))
    await model.send()
    #expect(service.sendCalls.first?.1 == String(repeating: "x", count: 500))
}

@Test @MainActor func failedOlderPagePreservesCurrentHistoryCursorAndDraft() async {
    let service = MessagingTestService()
    let message = ChatMessage(
        id: UUID(), conversationID: messagingThread.id, senderID: messagingPeer.id,
        clientMessageID: UUID(), body: "Already loaded", createdAt: messagingTime)
    let cursor = MessageCursor(time: messagingTime, id: message.id)
    service.historyPages = [
        MessagePage(conversation: messagingThread, messages: [message], nextCursor: cursor)
    ]
    let model = ChatModel(
        accountID: messagingOwner, target: .conversation(messagingThread.id), messagingService: service)
    await model.load()
    #expect(service.historyCursors.count == 1 && service.historyCursors[0] == nil)
    model.draft = "My draft"
    service.onHistory = { throw MessagingError.connection }
    await model.load(older: true)
    #expect(model.olderPageFailed && model.errorMessage != nil)
    #expect(model.messages == [message] && model.nextCursor == cursor)
    #expect(model.conversation != nil && model.draft == "My draft" && model.canSend)
    service.onHistory = nil
    await model.load(older: true)
    #expect(service.historyCursors[1] == cursor && service.historyCursors[2] == cursor)
    #expect(!model.olderPageFailed && model.messages == [message] && model.nextCursor == nil)
}

@Test @MainActor func draftLimitNeverSplitsComposedCharacters() {
    let model = ChatModel(
        accountID: messagingOwner, target: .peer(messagingPeer.id), messagingService: MessagingTestService())
    let prefix = String(repeating: "a", count: 499)
    model.draft = prefix + "👨‍👩‍👧‍👦"
    model.limitDraft()
    #expect(model.draft == prefix)
    model.draft = prefix + "e\u{301}"
    model.limitDraft()
    #expect(model.draft == prefix)
    model.draft = String(repeating: "😀", count: 501)
    model.limitDraft()
    #expect(model.draft == String(repeating: "😀", count: 500))
    #expect(MessageText.isValid(model.draft))
}

@Test @MainActor func uncertainSendReusesIdentityEvenAfterRefreshRecoversCommittedMessage() async throws {
    let service = MessagingTestService()
    let model = ChatModel(
        accountID: messagingOwner, target: .conversation(messagingThread.id), messagingService: service)
    await model.load()
    model.draft = "  Coffee\n \n\non   Saturday?  "
    var committed: ChatMessage?
    service.onSend = { retry, body in
        if let committed { return committed }
        committed = ChatMessage(
            id: UUID(), conversationID: messagingThread.id, senderID: messagingOwner,
            clientMessageID: retry, body: body, createdAt: messagingTime)
        throw MessagingError.connection  // The server committed, but its response was lost.
    }
    await model.send()
    let pending = model.pending
    #expect(pending != nil && !model.canSend)
    #expect(model.draft == "  Coffee\n \n\non   Saturday?  ")
    service.historyPages = [
        MessagePage(conversation: messagingThread, messages: [try #require(committed)], nextCursor: nil)
    ]
    await model.load()
    await model.retrySend()
    #expect(service.sendCalls.count == 2)
    #expect(service.sendCalls[0].0 == service.sendCalls[1].0)
    #expect(service.sendCalls[0].1 == service.sendCalls[1].1)
    #expect(service.sendCalls[0].1 == "Coffee\non Saturday?")
    #expect(model.messages.count == 1)
    #expect(model.pending == nil && model.draft.isEmpty && model.sendError == nil)
}

@Test @MainActor func unavailableConversationClearsMessagesDraftAndPendingSend() async {
    let service = MessagingTestService()
    let model = ChatModel(
        accountID: messagingOwner, target: .conversation(messagingThread.id), messagingService: service)
    await model.load()
    model.draft = "A private draft"
    service.onSend = { _, _ in throw MessagingError.connection }
    await model.send()
    service.onHistory = { throw MessagingError.unavailable }
    await model.load()
    #expect(model.messages.isEmpty && model.draft.isEmpty && model.pending == nil)
    #expect(model.conversation == nil && model.isUnavailable && !model.canSend)
}

@Test @MainActor func leavingAccountRejectsLateHistoryAndAllowsFreshReload() async {
    let service = MessagingTestService()
    let model = ChatModel(
        accountID: messagingOwner, target: .conversation(messagingThread.id), messagingService: service)
    let started = AsyncStream<Void>.makeStream()
    var events = started.stream.makeAsyncIterator()
    var response: CheckedContinuation<MessagePage, any Error>?
    service.onHistory = {
        try await withCheckedThrowingContinuation {
            response = $0
            started.continuation.yield(())
        }
    }
    let load = Task { await model.load() }
    await events.next()
    model.draft = "Private draft"
    model.reset()
    response?.resume(returning: MessagePage(conversation: messagingThread, messages: [], nextCursor: nil))
    await load.value
    #expect(model.conversation == nil && model.draft.isEmpty && !model.isLoading)
    service.onHistory = nil
    await model.load()
    #expect(model.conversation?.id == messagingThread.id)
    started.continuation.finish()
}

@Test @MainActor func leavingAccountRejectsLateSendResultAndClearsRetryState() async throws {
    let service = MessagingTestService()
    let model = ChatModel(
        accountID: messagingOwner, target: .conversation(messagingThread.id), messagingService: service)
    await model.load()
    let started = AsyncStream<Void>.makeStream()
    var events = started.stream.makeAsyncIterator()
    var response: CheckedContinuation<ChatMessage, any Error>?
    service.onSend = { _, _ in
        try await withCheckedThrowingContinuation {
            response = $0
            started.continuation.yield(())
        }
    }
    model.draft = "A private message"
    let send = Task { await model.send() }
    await events.next()
    let pending = try #require(model.pending)
    model.reset()
    response?.resume(
        returning: ChatMessage(
            id: UUID(), conversationID: messagingThread.id,
            senderID: messagingOwner, clientMessageID: pending.id, body: pending.body,
            createdAt: messagingTime))
    await send.value
    #expect(model.messages.isEmpty && model.pending == nil && model.draft.isEmpty && !model.isSending)
    started.continuation.finish()
}

@Test @MainActor func failedBlockHidesPrivateContentAndRetriesOnlyTheBlock() async {
    let service = MessagingTestService()
    let model = ChatModel(
        accountID: messagingOwner, target: .conversation(messagingThread.id), messagingService: service)
    await model.load()
    model.draft = "Private draft"
    service.blockFails = true
    await model.block()
    #expect(model.isUnavailable && model.blockFailed && model.draft.isEmpty)
    #expect(model.conversation == nil && model.messages.isEmpty)
    await model.load()
    #expect(model.conversation == nil)
    service.blockFails = false
    await model.block()
    #expect(!model.blockFailed && service.blocks == [messagingPeer.id, messagingPeer.id])
}

@Test @MainActor func cancelledInitialChatLoadOffersRecoveryInsteadOfBlankContent() async {
    let service = MessagingTestService()
    service.onHistory = {
        withUnsafeCurrentTask { $0?.cancel() }
        throw CancellationError()
    }
    let model = ChatModel(
        accountID: messagingOwner, target: .conversation(messagingThread.id), messagingService: service)
    await Task { await model.load() }.value
    #expect(!model.isLoading && model.errorMessage != nil)
    service.onHistory = nil
    await model.load()
    #expect(model.conversation != nil && model.errorMessage == nil)
}

@Test @MainActor func confirmedReportInvalidatesAnInflightSendAndClearsOnlyItsChat() async {
    let service = MessagingTestService()
    let model = ChatModel(
        accountID: messagingOwner, target: .conversation(messagingThread.id), messagingService: service)
    await model.load()
    model.draft = "Unsent plan"
    model.excludeProfiles([UUID()])
    #expect(model.conversation != nil && model.draft == "Unsent plan" && !model.isUnavailable)
    var response: CheckedContinuation<ChatMessage, Never>?
    service.onSend = { _, _ in await withCheckedContinuation { response = $0 } }
    let sending = Task { await model.send() }
    while response == nil { await Task.yield() }
    model.excludeProfiles([messagingPeer.id])
    let retry = service.sendCalls[0].0
    response?.resume(
        returning: ChatMessage(
            id: UUID(), conversationID: messagingThread.id,
            senderID: messagingOwner, clientMessageID: retry, body: "Unsent plan", createdAt: messagingTime))
    await sending.value
    #expect(model.conversation == nil && model.messages.isEmpty && model.draft.isEmpty)
    #expect(model.pending == nil && model.isUnavailable && !model.canSend)
}

@Test @MainActor func reportedPeerIsRejectedWhenAnUnknownThreadFinishesLoading() async {
    let service = MessagingTestService()
    let model = ChatModel(
        accountID: messagingOwner, target: .conversation(messagingThread.id), messagingService: service)
    model.excludeProfiles([messagingPeer.id])
    await model.load()
    #expect(model.conversation == nil && model.messages.isEmpty && model.isUnavailable)
}
