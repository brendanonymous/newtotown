import ImageIO
import NewToTownCore
import UIKit

/// Owned by one SignedInView, whose identity changes with the account UUID.
@MainActor final class ProfileImageStore {
    private struct Key: Hashable {
        let url: URL
        let pixels: Int
    }
    private struct Decoded: Sendable {
        let image: ProfileImagePixels
        let expiresAt: Date
    }
    private struct Entry {
        let photo: Decoded
        var lastUse: UInt64
    }
    private struct Request {
        let id: UUID
        let task: Task<Decoded, any Error>
    }
    private let loader: AuthorizedPhotoLoader
    private var cache: [Key: Entry] = [:]
    private var requests: [Key: Request] = [:]
    private var excluded: Set<UUID> = []
    private var cost = 0
    private var sequence: UInt64 = 0
    private var generation = 0
    private let maximumCost = 32 * 1024 * 1024

    init(loader: AuthorizedPhotoLoader = AuthorizedPhotoLoader()) { self.loader = loader }

    /// A read-only lookup lets an entering card render its preload on the first frame.
    /// The normal async request still records usage and handles a cache miss.
    func cachedImage(for url: URL, pixels: Int) -> UIImage? {
        guard !isExcluded(url), let resource = try? AuthorizedPhotoLoader.resourceURL(for: url),
            let entry = cache[Key(url: resource, pixels: max(1, min(1200, pixels)))],
            entry.photo.expiresAt > Date()
        else { return nil }
        return UIImage(cgImage: entry.photo.image.cgImage)
    }

    func image(for url: URL, pixels: Int) async throws -> UIImage {
        try Task.checkCancellation()
        guard !isExcluded(url) else { throw AuthorizedPhotoError.unavailable }
        // A new feed can renew the signature for the same object. Reuse only a
        // still-valid bitmap; its original deadline is never extended by a hit.
        let resource = try AuthorizedPhotoLoader.resourceURL(for: url)
        let key = Key(url: resource, pixels: max(1, min(1200, pixels)))
        sequence += 1
        if var entry = cache[key], entry.photo.expiresAt > Date() {
            entry.lastUse = sequence
            cache[key] = entry
            return UIImage(cgImage: entry.photo.image.cgImage)
        }
        remove(key)
        let current = generation
        let request: Request
        if let running = requests[key] {
            request = running
        } else {
            let loader = loader
            request = Request(
                id: UUID(),
                task: Task {
                    let source = try await loader.load(url)
                    return try await Task.detached(priority: .utility) {
                        let image = try ProfileImageDecoder.decode(source.data, pixels: key.pixels)
                        return Decoded(image: image, expiresAt: source.expiresAt)
                    }.value
                })
            requests[key] = request
        }
        do {
            let photo = try await request.task.value
            guard generation == current, !isExcluded(url), photo.expiresAt > Date() else {
                throw AuthorizedPhotoError.unavailable
            }
            if requests[key]?.id == request.id {
                requests[key] = nil
                store(photo, for: key)
            }
            try Task.checkCancellation()
            return UIImage(cgImage: photo.image.cgImage)
        } catch {
            if requests[key]?.id == request.id { requests[key] = nil }
            throw error
        }
    }

    func exclude(_ ids: Set<UUID>) {
        excluded.formUnion(ids)
        for key in Array(cache.keys) where isExcluded(key.url) { remove(key) }
        for key in Array(requests.keys) where isExcluded(key.url) {
            requests.removeValue(forKey: key)?.task.cancel()
        }
        Task { await loader.exclude(ids) }
    }

    func clear() {
        generation += 1
        for request in requests.values { request.task.cancel() }
        requests.removeAll()
        cache.removeAll()
        cost = 0
        Task { await loader.clear() }
    }

    private func store(_ photo: Decoded, for key: Key) {
        let imageCost = photo.image.cgImage.bytesPerRow * photo.image.cgImage.height
        guard imageCost <= maximumCost else { return }
        while cost + imageCost > maximumCost,
            let oldest = cache.min(by: { $0.value.lastUse < $1.value.lastUse })?.key
        {
            remove(oldest)
        }
        sequence += 1
        cache[key] = Entry(photo: photo, lastUse: sequence)
        cost += imageCost
    }

    private func remove(_ key: Key) {
        if let entry = cache.removeValue(forKey: key) {
            cost -= entry.photo.image.cgImage.bytesPerRow * entry.photo.image.cgImage.height
        }
    }

    private func isExcluded(_ url: URL) -> Bool {
        UUID(uuidString: url.deletingLastPathComponent().lastPathComponent)
            .map { excluded.contains($0) } ?? false
    }
}
