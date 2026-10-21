import Foundation
import Supabase

@testable import NewToTownSupabase

/// Each test gets its own URL host, session, Auth storage, and HTTP responses.
final class MessagingHTTPFixture: @unchecked Sendable {
    let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
    let peer = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
    let thread = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
    let time = "2026-10-17T23:00:00.123456+00:00"
    private let lock = NSLock()
    private var user: UUID
    private var status = 200
    private var payload = Data("{}".utf8)
    private var calls: [URLRequest] = []
    private var hold = false
    private var pending: (@Sendable () -> Void)?
    let started = AsyncStream<Void>.makeStream()
    let host = UUID().uuidString.lowercased() + ".test"
    let session: URLSession
    let client: SupabaseClient
    let configuration: SupabaseConfiguration

    init() throws {
        user = owner
        configuration = try SupabaseConfiguration(
            projectURL: "https://\(host)", publishableKey: "sb_publishable_test")
        let settings = URLSessionConfiguration.ephemeral
        settings.protocolClasses = [MessagingURLProtocol.self]
        session = URLSession(configuration: settings)
        client = SupabaseClient(
            supabaseURL: configuration.projectURL, supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(storage: MessagingMemoryStorage(), autoRefreshToken: false),
                global: .init(session: session)))
        MessagingURLProtocol.registry.register(self, host: host)
    }
    deinit {
        MessagingURLProtocol.registry.remove(host: host)
        session.invalidateAndCancel()
        started.continuation.finish()
    }
    func signIn(_ id: UUID? = nil) async throws -> String {
        let id = id ?? owner
        lock.withLock { user = id }
        let payload = try JSONSerialization.data(withJSONObject: [
            "sub": id.uuidString, "exp": Date().timeIntervalSince1970 + 3600,
        ])
        .base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(
            of: "/", with: "_"
        ).replacingOccurrences(of: "=", with: "")
        let token = "eyJhbGciOiJIUzI1NiJ9.\(payload).test-signature"
        try await client.auth.setSession(accessToken: token, refreshToken: "test-refresh")
        return token
    }
    func service() -> SupabaseMessagingService {
        SupabaseMessagingService(
            client: client, accountID: owner, configuration: configuration, session: session)
    }
    func respond(_ object: Any, status: Int = 200, hold: Bool = false) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        lock.withLock {
            self.status = status
            payload = data
            self.hold = hold
        }
    }
    func release() {
        let completion = lock.withLock {
            let value = pending
            pending = nil
            return value
        }
        completion?()
    }
    var functionRequests: [URLRequest] {
        lock.withLock { calls.filter { $0.url?.path.contains("/functions/") == true } }
    }
    func receive(_ request: URLRequest, reply: @escaping @Sendable (Int, Data) -> Void) {
        let deferred: Bool = lock.withLock {
            var recorded = request
            if recorded.httpBody == nil, let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var data = Data()
                var bytes = [UInt8](repeating: 0, count: 4096)
                while true {
                    let count = stream.read(&bytes, maxLength: bytes.count)
                    if count <= 0 { break }
                    data.append(contentsOf: bytes.prefix(count))
                }
                recorded.httpBody = data
            }
            calls.append(recorded)
            if request.url?.path.contains("/functions/") == true {
                let status = status
                let data = payload
                if hold {
                    pending = { reply(status, data) }
                    return true
                }
                reply(status, data)
            } else if request.url?.path.hasSuffix("/user") == true {
                let data = try! JSONSerialization.data(withJSONObject: [
                    "id": user.uuidString, "aud": "authenticated",
                    "created_at": "2026-10-17T00:00:00Z", "updated_at": "2026-10-17T00:00:00Z",
                ])
                reply(200, data)
            } else {
                reply(204, Data())
            }
            return false
        }
        if deferred { started.continuation.yield(()) }
    }
    var conversationJSON: [String: Any] {
        [
            "id": thread.uuidString, "created_at": time, "last_activity_at": time, "last_message": NSNull(),
            "participant": [
                "id": peer.uuidString, "first_name": "Alex", "job_title": "Designer",
                "goal": "Find a hiking buddy.",
                "city": "Scottsdale", "photo_url": "https://example.test/profile.jpg",
            ],
        ]
    }
    func messageJSON(retry: UUID, body: String) -> [String: Any] {
        [
            "id": UUID().uuidString, "conversation_id": thread.uuidString, "sender_id": owner.uuidString,
            "client_message_id": retry.uuidString, "body": body, "created_at": time,
        ]
    }
}

private final class MessagingMemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) { lock.withLock { values[key] = value } }
    func retrieve(key: String) -> Data? { lock.withLock { values[key] } }
    func remove(key: String) { lock.withLock { values[key] = nil } }
}

private final class MessagingURLProtocol: URLProtocol, @unchecked Sendable {
    final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [String: WeakFixture] = [:]
        func register(_ fixture: MessagingHTTPFixture, host: String) {
            lock.withLock { entries[host] = WeakFixture(value: fixture) }
        }
        func remove(host: String) { lock.withLock { entries[host] = nil } }
        func fixture(host: String) -> MessagingHTTPFixture? { lock.withLock { entries[host]?.value } }
    }
    private final class WeakFixture {
        weak var value: MessagingHTTPFixture?
        init(value: MessagingHTTPFixture) { self.value = value }
    }
    static let registry = Registry()
    override class func canInit(with request: URLRequest) -> Bool {
        registry.fixture(host: request.url?.host ?? "") != nil
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let fixture = Self.registry.fixture(host: url.host ?? "") else { return }
        fixture.receive(request) { status, data in
            let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}
