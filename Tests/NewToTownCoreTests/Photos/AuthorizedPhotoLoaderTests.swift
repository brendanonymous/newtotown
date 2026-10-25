import Foundation
import Testing

@testable import NewToTownCore

private final class PhotoClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1000)
    func now() -> Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date.addTimeInterval(seconds) } }
}

private actor PhotoDownloadStub {
    var calls = 0
    var held: CheckedContinuation<Data, any Error>?
    var holdFirst = false
    var failFirst = false
    func configure(hold: Bool = false, fail: Bool = false) {
        holdFirst = hold
        failFirst = fail
    }
    func download(_ url: URL) async throws -> Data {
        calls += 1
        if calls == 1, failFirst { throw AuthorizedPhotoError.unavailable }
        if calls == 1, holdFirst { return try await withCheckedThrowingContinuation { held = $0 } }
        return Data([1, 2])
    }
    func release() {
        held?.resume(returning: Data([1, 2]))
        held = nil
    }
}

private func photoURL(expiry: Int = 1060, version: String = "one", owner: UUID = UUID()) -> URL {
    let claims = Data("{\"exp\":\(expiry)}".utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    return URL(
        string:
            "https://photos.example.test/storage/v1/object/sign/private-photos/\(owner)/profile.jpg?token=header.\(claims).\(version)"
    )!
}

@Test func concurrentPhotoConsumersShareARequestAndCancellationDoesNotCancelOthers() async throws {
    let clock = PhotoClock()
    let stub = PhotoDownloadStub()
    await stub.configure(hold: true)
    let loader = AuthorizedPhotoLoader(now: { clock.now() }, download: { try await stub.download($0) })
    let url = photoURL()
    let first = Task { try await loader.load(url) }
    while await stub.held == nil { await Task.yield() }
    let second = Task { try await loader.load(url) }
    first.cancel()
    await stub.release()
    await #expect(throws: CancellationError.self) { try await first.value }
    #expect(try await second.value.data == Data([1, 2]))
    #expect(try await loader.load(url).data == Data([1, 2]))
    #expect(await stub.calls == 1)
}

@Test func photoCacheUsesTheWholeSignedURLAndHonorsExpiry() async throws {
    let clock = PhotoClock()
    let stub = PhotoDownloadStub()
    let loader = AuthorizedPhotoLoader(now: { clock.now() }, download: { try await stub.download($0) })
    let owner = UUID()
    let original = photoURL(owner: owner)
    _ = try await loader.load(original)
    _ = try await loader.load(original)
    _ = try await loader.load(photoURL(version: "replacement", owner: owner))
    #expect(await stub.calls == 2)
    clock.advance(61)
    await #expect(throws: AuthorizedPhotoError.expired) { try await loader.load(original) }
    #expect(await stub.calls == 2)
    _ = try await loader.load(photoURL(expiry: 1120, owner: owner))
    #expect(await stub.calls == 3)
}

@Test func photoCacheEvictsLeastRecentlyUsedBytesAndDoesNotCacheFailures() async throws {
    let clock = PhotoClock()
    let stub = PhotoDownloadStub()
    await stub.configure(fail: true)
    let loader = AuthorizedPhotoLoader(
        maximumBytes: 4, now: { clock.now() }, download: { try await stub.download($0) })
    let first = photoURL()
    let second = photoURL()
    let third = photoURL()
    await #expect(throws: AuthorizedPhotoError.unavailable) { try await loader.load(first) }
    _ = try await loader.load(first)
    _ = try await loader.load(second)
    _ = try await loader.load(first)
    _ = try await loader.load(third)
    _ = try await loader.load(first)
    #expect(await stub.calls == 4)
    _ = try await loader.load(second)
    #expect(await stub.calls == 5)
}

@Test func clearingAnAccountRejectsLatePhotosAndDoesNotPopulateItsCache() async throws {
    let clock = PhotoClock()
    let stub = PhotoDownloadStub()
    await stub.configure(hold: true)
    let loader = AuthorizedPhotoLoader(now: { clock.now() }, download: { try await stub.download($0) })
    let url = photoURL()
    let load = Task { try await loader.load(url) }
    while await stub.held == nil { await Task.yield() }
    await loader.clear()
    await stub.release()
    await #expect(throws: AuthorizedPhotoError.unavailable) { try await load.value }
    _ = try await loader.load(url)
    #expect(await stub.calls == 2)
    let anotherAccount = AuthorizedPhotoLoader(
        now: { clock.now() }, download: { try await stub.download($0) })
    _ = try await anotherAccount.load(url)
    #expect(await stub.calls == 3)
}

@Test func reportingEvictsOnlyThatPeerAndRejectsAnInflightPhoto() async throws {
    let clock = PhotoClock()
    let stub = PhotoDownloadStub()
    await stub.configure(hold: true)
    let loader = AuthorizedPhotoLoader(now: { clock.now() }, download: { try await stub.download($0) })
    let owner = UUID()
    let peer = photoURL()
    let url = photoURL(owner: owner)
    let load = Task { try await loader.load(url) }
    while await stub.held == nil { await Task.yield() }
    _ = try await loader.load(peer)
    await loader.exclude([owner])
    await stub.release()
    await #expect(throws: AuthorizedPhotoError.unavailable) { try await load.value }
    await #expect(throws: AuthorizedPhotoError.unavailable) { try await loader.load(url) }
    _ = try await loader.load(peer)
    #expect(await stub.calls == 2)
}

@Test func photoLoaderRejectsUnsignedPhotosSelfiesAndOversizedResponses() async throws {
    let clock = PhotoClock()
    let stub = PhotoDownloadStub()
    let loader = AuthorizedPhotoLoader(now: { clock.now() }, download: { try await stub.download($0) })
    let unsigned = URL(string: "https://photos.example.test/\(UUID())/profile.jpg")!
    await #expect(throws: AuthorizedPhotoError.invalidURL) { try await loader.load(unsigned) }
    let selfie = URL(
        string: photoURL().absoluteString.replacingOccurrences(of: "profile.jpg", with: "selfie.jpg"))!
    await #expect(throws: AuthorizedPhotoError.invalidURL) { try await loader.load(selfie) }
    #expect(await stub.calls == 0)
    let oversized = AuthorizedPhotoLoader(
        now: { clock.now() }, download: { _ in Data(count: PrivatePhotos.maximumFileSize + 1) })
    await #expect(throws: AuthorizedPhotoError.invalidData) { try await oversized.load(photoURL()) }
}
