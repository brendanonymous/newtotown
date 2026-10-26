import Foundation

public struct AuthorizedPhotoData: Sendable {
    public let data: Data
    public let expiresAt: Date
}

public enum AuthorizedPhotoError: Error, Equatable {
    case invalidURL, expired, unavailable, invalidData
}

/// One instance per signed-in account. Private photos never enter a disk cache.
public actor AuthorizedPhotoLoader {
    public typealias Download = @Sendable (URL) async throws -> Data
    private struct Entry {
        let photo: AuthorizedPhotoData
        var lastUse: UInt64
    }
    private struct Request {
        let id: UUID
        let task: Task<Data, any Error>
    }
    private let download: Download
    private let now: @Sendable () -> Date
    private let maximumBytes: Int
    private var cache: [URL: Entry] = [:]
    private var requests: [URL: Request] = [:]
    private var excluded: Set<UUID> = []
    private var bytes = 0
    private var sequence: UInt64 = 0
    private var generation = 0

    public init(
        maximumBytes: Int = 8 * 1024 * 1024,
        now: @escaping @Sendable () -> Date = { Date() },
        download: Download? = nil
    ) {
        self.maximumBytes = max(0, maximumBytes)
        self.now = now
        if let download {
            self.download = download
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: configuration)
            self.download = { url in
                let (data, response) = try await session.data(from: url)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                    response.mimeType?.hasPrefix("image/") == true
                else { throw AuthorizedPhotoError.unavailable }
                return data
            }
        }
    }

    public func load(_ url: URL) async throws -> AuthorizedPhotoData {
        try Task.checkCancellation()
        let owner = try Self.owner(of: url)
        guard !excluded.contains(owner) else { throw AuthorizedPhotoError.unavailable }
        let expiresAt = try Self.expiry(of: url, now: now())
        purgeExpired()
        sequence += 1
        if var entry = cache[url] {
            entry.lastUse = sequence
            cache[url] = entry
            return entry.photo
        }
        let current = generation
        let request: Request
        if let running = requests[url] {
            request = running
        } else {
            let download = download
            request = Request(id: UUID(), task: Task { try await download(url) })
            requests[url] = request
        }
        do {
            let data = try await request.task.value
            guard current == generation, !excluded.contains(owner) else {
                throw AuthorizedPhotoError.unavailable
            }
            guard expiresAt > now() else { throw AuthorizedPhotoError.expired }
            guard !data.isEmpty, data.count <= PrivatePhotos.maximumFileSize else {
                throw AuthorizedPhotoError.invalidData
            }
            let photo = AuthorizedPhotoData(data: data, expiresAt: expiresAt)
            if requests[url]?.id == request.id {
                requests[url] = nil
                store(photo, for: url)
            }
            // A disappearing consumer must not cancel the shared download for other views.
            try Task.checkCancellation()
            return photo
        } catch {
            if requests[url]?.id == request.id { requests[url] = nil }
            throw error
        }
    }

    public func exclude(_ profileIDs: Set<UUID>) {
        excluded.formUnion(profileIDs)
        for url in Array(cache.keys) where Self.isExcluded(url, by: excluded) { remove(url) }
        for url in Array(requests.keys) where Self.isExcluded(url, by: excluded) {
            requests.removeValue(forKey: url)?.task.cancel()
        }
    }

    public func clear() {
        generation += 1
        for request in requests.values { request.task.cancel() }
        requests.removeAll()
        cache.removeAll()
        bytes = 0
    }

    /// Stable identity for a currently valid signed photo, suitable for an
    /// account-scoped decoded-image cache. Keep the downloaded source's expiry;
    /// this validates retention bounds, not the signature (Storage does that).
    public static func resourceURL(for url: URL, now: Date = Date()) throws -> URL {
        _ = try owner(of: url)
        _ = try expiry(of: url, now: now)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.host != nil,
            components.queryItems?.filter({ $0.name == "token" }).count == 1
        else { throw AuthorizedPhotoError.invalidURL }
        components.queryItems = components.queryItems?.filter { $0.name != "token" }
        if components.queryItems?.isEmpty == true { components.queryItems = nil }
        components.fragment = nil
        guard let resource = components.url else { throw AuthorizedPhotoError.invalidURL }
        return resource
    }

    private func store(_ photo: AuthorizedPhotoData, for url: URL) {
        guard photo.data.count <= maximumBytes else { return }
        remove(url)
        while bytes + photo.data.count > maximumBytes,
            let oldest = cache.min(by: { $0.value.lastUse < $1.value.lastUse })?.key
        {
            remove(oldest)
        }
        sequence += 1
        cache[url] = Entry(photo: photo, lastUse: sequence)
        bytes += photo.data.count
    }

    private func purgeExpired() {
        for (url, entry) in cache where entry.photo.expiresAt <= now() { remove(url) }
    }

    private func remove(_ url: URL) {
        if let entry = cache.removeValue(forKey: url) { bytes -= entry.photo.data.count }
    }

    private static func owner(of url: URL) throws -> UUID {
        guard url.scheme == "https",
            ["profile.jpg", "profile-2.jpg", "profile-3.jpg"].contains(url.lastPathComponent),
            let owner = UUID(uuidString: url.deletingLastPathComponent().lastPathComponent)
        else { throw AuthorizedPhotoError.invalidURL }
        return owner
    }

    private static func isExcluded(_ url: URL, by ids: Set<UUID>) -> Bool {
        (try? owner(of: url)).map { ids.contains($0) } ?? false
    }

    private static func expiry(of url: URL, now: Date) throws -> Date {
        guard
            let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "token" })?.value
        else { throw AuthorizedPhotoError.invalidURL }
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { throw AuthorizedPhotoError.invalidURL }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
            let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let expiry = claims["exp"] as? TimeInterval, expiry.isFinite
        else { throw AuthorizedPhotoError.invalidURL }
        // Reading exp only bounds local retention; Storage verifies the actual signature.
        let deadline = min(Date(timeIntervalSince1970: expiry), now.addingTimeInterval(60))
        guard deadline > now else { throw AuthorizedPhotoError.expired }
        return deadline
    }
}
