import Foundation
import NewToTownCore
import Supabase

/// A lightweight Functions client bound to the owner of this signed-in app shell.
/// Auth/session refresh still belongs to the single shared Supabase client.
public final class SupabaseMessagingService: MessagingService {
    private let functions: FunctionsClient
    private let accountID: UUID

    init(
        client: SupabaseClient, accountID: UUID, configuration: SupabaseConfiguration,
        session: URLSession = .shared
    ) {
        self.accountID = accountID
        functions = FunctionsClient(
            url: configuration.projectURL.appendingPathComponent("functions/v1"),
            headers: ["apikey": configuration.publishableKey],
            fetch: { request in
                let credentials: Session
                do { credentials = try await client.auth.session } catch AuthError.sessionMissing {
                    throw MessagingError.signedOut
                }
                guard credentials.user.id == accountID, !Task.isCancelled else {
                    throw MessagingError.signedOut
                }
                var request = request
                request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
                let response = try await session.data(for: request)
                guard client.auth.currentSession?.user.id == accountID else { throw MessagingError.signedOut }
                return response
            }
        )
    }

    public func conversations(before cursor: MessageCursor?) async throws -> ConversationPage {
        let page: ConversationPage = try await invoke(Command(action: "list", cursor: cursor))
        guard page.conversations.count <= 50,
            page.conversations.allSatisfy({ $0.participant.id != accountID })
        else {
            throw MessagingError.connection
        }
        return page
    }
    public func open(with peerID: UUID) async throws -> Conversation {
        let thread: Conversation = try await invoke(Command(action: "open", targetID: peerID))
        guard thread.participant.id == peerID, peerID != accountID else { throw MessagingError.connection }
        return thread
    }
    public func history(in conversationID: UUID, before cursor: MessageCursor?) async throws -> MessagePage {
        let page: MessagePage = try await invoke(
            Command(action: "history", conversationID: conversationID, cursor: cursor))
        guard page.conversation.id == conversationID, page.conversation.participant.id != accountID,
            page.messages.count <= 50,
            page.messages.allSatisfy({
                $0.conversationID == conversationID
                    && ($0.senderID == accountID || $0.senderID == page.conversation.participant.id)
            })
        else { throw MessagingError.connection }
        return page
    }
    public func send(in conversationID: UUID, retryID: UUID, body: String) async throws -> ChatMessage {
        guard MessageText.isValid(body) else { throw MessagingError.invalidMessage }
        let sent: ChatMessage = try await invoke(
            Command(action: "send", conversationID: conversationID, clientMessageID: retryID, body: body))
        guard sent.conversationID == conversationID, sent.senderID == accountID,
            sent.clientMessageID == retryID, sent.body == body
        else { throw MessagingError.connection }
        return sent
    }
    public func block(_ peerID: UUID) async throws {
        do {
            try await functions.invoke(
                "discovery",
                options: FunctionInvokeOptions(
                    body: BlockCommand(targetID: peerID), timeoutInterval: 45))
        } catch { throw translated(error) }
    }

    private func invoke<T: Decodable>(_ command: Command) async throws -> T {
        do {
            return try await functions.invoke(
                "messaging", options: FunctionInvokeOptions(body: command, timeoutInterval: 45))
        } catch { throw translated(error) }
    }
    private func translated(_ error: Error) -> Error {
        if let typed = error as? MessagingError { return typed }
        if case FunctionsError.httpError(let status, _) = error {
            switch status {
            case 401: return MessagingError.signedOut
            case 404: return MessagingError.unavailable
            case 400: return MessagingError.invalidMessage
            case 409: return MessagingError.retryConflict
            default: break
            }
        }
        return MessagingError.connection
    }
}

private struct Command: Encodable {
    let action: String
    var targetID: UUID? = nil
    var conversationID: UUID? = nil
    var clientMessageID: UUID? = nil
    var body: String? = nil
    var cursor: MessageCursor? = nil
    enum CodingKeys: String, CodingKey {
        case action, body, cursor
        case targetID = "target_id"
        case conversationID = "conversation_id"
        case clientMessageID = "client_message_id"
    }
}
private struct BlockCommand: Encodable {
    let action = "block"
    let targetID: UUID
    enum CodingKeys: String, CodingKey {
        case action
        case targetID = "target_id"
    }
}
