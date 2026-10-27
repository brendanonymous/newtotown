#if DEBUG
    import Foundation
    import NewToTownCore
    import SwiftUI
    import UIKit

    /// Offline dependencies for simulator UI tests only. Compiled out of release builds.
    struct MessagingJourneyFixture: View {
        @State private var account = OnboardingModel(service: JourneyAccountService())
        private let first = JourneyMessagingService(
            owner: JourneyIDs.first, name: "Alex", marker: "Account A conversation",
            startsEmpty: ProcessInfo.processInfo.arguments.contains("--ui-test-empty-chat"))
        private let second = JourneyMessagingService(
            owner: JourneyIDs.second, name: "Taylor", marker: "Account B conversation")

        private let firstContacts = ContactJourneyService()
        private let secondContacts = ContactJourneyService()
        private let firstInterests = InterestJourneyService()
        private let secondInterests = InterestJourneyService()
        private let firstPreferences = JourneyPreferencesService()
        private let secondPreferences = JourneyPreferencesService()
        @State private var layoutPhotos = LayoutJourneyServices.photos(
            saved: ProcessInfo.processInfo.arguments.contains("--ui-test-saved-photo"))
        @State private var firstImages = JourneyPhoto.store()
        @State private var secondImages = JourneyPhoto.store()

        var body: some View {
            AppEntryView(
                model: account,
                personalInfoService: ProcessInfo.processInfo.arguments.contains("--ui-test-contacts")
                    ? (account.accountID == JourneyIDs.second ? secondContacts : firstContacts) : nil,
                photoService: ProcessInfo.processInfo.arguments.contains("--ui-test-photos")
                    ? layoutPhotos : nil,
                discoveryService: JourneyDiscoveryService(
                    messages: account.accountID == JourneyIDs.second ? second : first),
                makeMessagingService: { id in id == JourneyIDs.second ? second : first },
                makeDiscoveryPreferencesService: { id in
                    id == JourneyIDs.second ? secondPreferences : firstPreferences
                },
                makeReportingService: { id in
                    JourneyReportingService(messages: id == JourneyIDs.second ? second : first)
                },
                makeInterestsService: { id in id == JourneyIDs.second ? secondInterests : firstInterests },
                makeContactsService: { id in id == JourneyIDs.second ? secondContacts : firstContacts }
            )
            .onChange(of: account.step) { _, step in
                if step == .profile && ProcessInfo.processInfo.arguments.contains("--ui-test-new-profile") {
                    var draft = ProfileDraft()
                    draft.firstName = "New member"
                    draft.jobTitle = "Designer"
                    draft.goal = "Find a hiking buddy."
                    draft.dateOfBirth = "1990-01-01"
                    draft.platonicAgreement = true
                    account.draft = draft
                }
            }
            .environment(
                \.profileImages,
                ProcessInfo.processInfo.arguments.contains("--ui-test-profile-images")
                    ? (account.accountID == JourneyIDs.second ? secondImages : firstImages) : nil)
        }
    }

    @MainActor private enum JourneyPhoto {
        static func store() -> ProfileImageStore {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
                UIColor(red: 0.75, green: 0.78, blue: 0.68, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            }
            let data = image.jpegData(compressionQuality: 0.8)!
            return ProfileImageStore(loader: AuthorizedPhotoLoader(download: { _ in data }))
        }

        static func urlForSlot(_ slot: Int) -> URL {
            URL(
                string: url.absoluteString.replacingOccurrences(
                    of: "profile.jpg", with: "profile-\(slot).jpg"))!
        }

        static var url: URL {
            let expiry = Int(Date().addingTimeInterval(60).timeIntervalSince1970)
            let claims = Data("{\"exp\":\(expiry)}".utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            return URL(
                string:
                    "https://fixture.example.test/\(JourneyIDs.peer)/profile.jpg?token=header.\(claims).signature"
            )!
        }
    }

    private actor JourneyReportingService: ProfileReportingService {
        let messages: JourneyMessagingService
        private var receipts: Set<UUID> = []
        init(messages: JourneyMessagingService) { self.messages = messages }
        func submit(_ report: ProfileReport) async throws -> UUID {
            await messages.block(report.targetID)
            if receipts.insert(report.retryID).inserted
                && ProcessInfo.processInfo.arguments.contains("--ui-test-report-lost-response")
            {
                throw ProfileReportingError.connection
            }
            return report.retryID
        }
    }

    private actor JourneyPreferencesService: DiscoveryPreferencesService {
        private var value = AgePreferences()
        func load() -> AgePreferences { value }
        func save(_ preferences: AgePreferences) -> AgePreferences {
            value = preferences
            return value
        }
    }

    private enum JourneyIDs {
        static let first = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
        static let second = UUID(uuidString: "00000000-0000-0000-0000-000000000043")!
        static let peer = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        static let thread = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
        static let time = "2026-10-17T23:00:00.123456Z"
    }

    private actor JourneyAccountService: OnboardingService {
        private var owner: UUID? = JourneyIDs.first
        private var savedProfiles: [UUID: Profile] = [:]
        func currentUserID() async throws -> UUID? {
            if ProcessInfo.processInfo.arguments.contains("--ui-test-loading") {
                try await Task.sleep(for: .seconds(30))
            }
            return owner
        }
        func sendCode(to identifier: SignInIdentifier) {}
        func verifyCode(_ code: String, identifier: SignInIdentifier) -> UUID {
            owner = JourneyIDs.second
            return JourneyIDs.second
        }
        func hasAcceptedAgreement(for userID: UUID) -> Bool { true }
        func acceptAgreement(for userID: UUID) {}
        func save(_ profile: Profile) { savedProfiles[profile.id] = profile }
        func profile(for userID: UUID) throws -> Profile? {
            if let profile = savedProfiles[userID] { return profile }
            if ProcessInfo.processInfo.arguments.contains("--ui-test-new-profile") { return nil }
            var draft = ProfileDraft()
            draft.firstName = "Fixture member"
            draft.jobTitle = "Designer"
            draft.goal = "Find a hiking buddy."
            draft.dateOfBirth = "1990-01-01"
            draft.platonicAgreement = true
            return try Profile(id: userID, draft: draft)
        }
        func signOut() { owner = nil }
        func deleteAccount() { owner = nil }
    }

    @MainActor private final class JourneyMessagingService: MessagingService {
        private let owner: UUID
        private let marker: String
        private let startsEmpty: Bool
        var hasStarted: Bool { !startsEmpty || !sent.isEmpty }
        private var sent: [ChatMessage] = []
        private var failedFirstSend = false
        private(set) var blocked = false
        let thread: Conversation

        init(owner: UUID, name: String, marker: String, startsEmpty: Bool = false) {
            self.owner = owner
            self.marker = marker
            self.startsEmpty = startsEmpty
            let peer = DiscoveryProfile(
                id: JourneyIDs.peer, firstName: name, jobTitle: "Designer",
                goal: ProcessInfo.processInfo.arguments.contains("--ui-test-discovery-layout")
                    ? "Find friends for coffee, hiking, professional networking, local volunteering and relaxed weekend dinners."
                    : "Find a hiking buddy.", city: "Scottsdale",
                photoURL: ProcessInfo.processInfo.arguments.contains("--ui-test-profile-images")
                    ? JourneyPhoto.url : URL(fileURLWithPath: "/uitest-photo-placeholder"),
                photoURLs: ProcessInfo.processInfo.arguments.contains("--ui-test-photo-gallery")
                    ? [JourneyPhoto.url, JourneyPhoto.urlForSlot(2), JourneyPhoto.urlForSlot(3)] : nil)
            thread = Conversation(
                id: JourneyIDs.thread, participant: peer, createdAt: JourneyIDs.time,
                lastActivityAt: JourneyIDs.time, lastMessage: nil)
        }
        private var greeting: ChatMessage {
            ChatMessage(
                id: JourneyIDs.peer, conversationID: thread.id, senderID: JourneyIDs.peer,
                clientMessageID: JourneyIDs.peer, body: marker, createdAt: JourneyIDs.time)
        }
        func conversations(before cursor: MessageCursor?) throws -> ConversationPage {
            let summary = Conversation(
                id: thread.id, participant: thread.participant, createdAt: thread.createdAt,
                lastActivityAt: thread.lastActivityAt, lastMessage: sent.last ?? greeting)
            return ConversationPage(conversations: blocked || !hasStarted ? [] : [summary], nextCursor: nil)
        }
        func open(with peerID: UUID) throws -> Conversation {
            guard !blocked else { throw MessagingError.unavailable }
            return thread
        }
        func history(in conversationID: UUID, before cursor: MessageCursor?) throws -> MessagePage {
            guard !blocked else { throw MessagingError.unavailable }
            if ProcessInfo.processInfo.arguments.contains("--ui-test-long-history") {
                let range = cursor == nil ? 21...70 : 1...20
                let messages = range.map { index in
                    ChatMessage(
                        id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1000))!,
                        conversationID: thread.id, senderID: JourneyIDs.peer,
                        clientMessageID: UUID(), body: "History message \(index)",
                        createdAt: ISO8601DateFormatter().string(
                            from: Date(timeIntervalSince1970: Double(index))))
                }
                let oldest = messages[0]
                return MessagePage(
                    conversation: thread, messages: messages,
                    nextCursor: cursor == nil ? MessageCursor(time: oldest.createdAt, id: oldest.id) : nil)
            }
            return MessagePage(
                conversation: thread, messages: (startsEmpty ? [] : [greeting]) + sent, nextCursor: nil)
        }
        func send(in conversationID: UUID, retryID: UUID, body: String) throws -> ChatMessage {
            guard !blocked else { throw MessagingError.unavailable }
            if let previous = sent.first(where: { $0.clientMessageID == retryID }) { return previous }
            let message = ChatMessage(
                id: retryID, conversationID: thread.id, senderID: owner,
                clientMessageID: retryID, body: body, createdAt: JourneyIDs.time)
            sent.append(message)
            if !failedFirstSend {
                failedFirstSend = true
                throw MessagingError.connection
            }
            return message
        }
        func block(_ peerID: UUID) { blocked = true }
    }

    @MainActor private final class JourneyDiscoveryService: DiscoveryService {
        let messages: JourneyMessagingService
        private var visible = true
        init(messages: JourneyMessagingService) { self.messages = messages }
        func load() -> DiscoveryFeed {
            DiscoveryFeed(
                state: visible ? .ready : .hidden, visible: visible,
                candidates: ProcessInfo.processInfo.arguments.contains("--ui-test-discovery-layout")
                    && !messages.blocked
                    ? [messages.thread.participant] : [],
                matches: !visible || messages.blocked || messages.hasStarted
                    ? [] : [messages.thread.participant])
        }
        func setVisible(_ visible: Bool) -> DiscoveryFeed {
            self.visible = visible
            return load()
        }
        func decide(on profileID: UUID, choice: ConnectionChoice) -> DiscoveryFeed { load() }
        func block(_ profileID: UUID) -> DiscoveryFeed {
            messages.block(profileID)
            return load()
        }
    }
#endif
