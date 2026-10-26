#if DEBUG
    import NewToTownCore
    import Observation
    import SwiftUI
    import UIKit

    /// Offline, manually completed decisions prove that a tap never advances
    /// before acknowledgement. Counters detect redundant or excessive preloads.
    struct DiscoveryTransitionJourneyFixture: View {
        @State private var service = TransitionDiscoveryService()
        @State private var probe: TransitionPhotoProbe
        @State private var images: ProfileImageStore

        init() {
            let probe = TransitionPhotoProbe()
            _probe = State(initialValue: probe)
            _images = State(
                initialValue: ProfileImageStore(
                    loader: AuthorizedPhotoLoader(download: { try await probe.download($0) })))
        }

        var body: some View {
            NavigationStack {
                DiscoveryView(service: service, isSelected: true, reportedProfileIDs: [])
                    .safeAreaInset(edge: .bottom) {
                        VStack {
                            Text("Sam main downloads: \(probe.count(owner: TransitionPeople.sam, slot: 1))")
                                .accessibilityIdentifier("fixture.samDownloads")
                            Text("Sam extra downloads: \(probe.count(owner: TransitionPeople.sam, slot: 2))")
                                .accessibilityIdentifier("fixture.samExtraDownloads")
                            Text("Taylor downloads: \(probe.count(owner: TransitionPeople.taylor, slot: 1))")
                                .accessibilityIdentifier("fixture.taylorDownloads")
                            if service.isSaving {
                                Button("Finish decision") { service.finish() }
                            }
                        }
                        .font(.caption).padding(8).background(BrandTheme.background)
                    }
            }
            .environment(\.profileImages, images)

        }
    }

    private enum TransitionPeople {
        static let alex = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        static let sam = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        static let taylor = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!

        static func profile(_ id: UUID, name: String, revision: Int, slots: Int = 1) -> DiscoveryProfile {
            let expiry = Int(Date().addingTimeInterval(60).timeIntervalSince1970)
            let payload = Data("{\"exp\":\(expiry)}".utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            let photos = (1...slots).map { slot in
                let name = slot == 1 ? "profile.jpg" : "profile-\(slot).jpg"
                return URL(
                    string:
                        "https://fixture.example.test/storage/v1/object/sign/private-photos/\(id)/\(name)?token=header.\(payload).revision\(revision)"
                )!
            }
            return DiscoveryProfile(
                id: id, firstName: name, jobTitle: "Designer",
                goal: "Find a hiking buddy.", city: "Scottsdale", photoURL: photos[0], photoURLs: photos)
        }
    }

    @MainActor @Observable private final class TransitionDiscoveryService: DiscoveryService {
        private var index = 0
        private var revision = 0
        private var response: CheckedContinuation<Void, Never>?
        var isSaving = false
        private var fails = ProcessInfo.processInfo.arguments.contains("--ui-test-decision-fails")

        func load() -> DiscoveryFeed {
            let profiles = [
                TransitionPeople.profile(TransitionPeople.alex, name: "Alex", revision: revision),
                TransitionPeople.profile(TransitionPeople.sam, name: "Sam", revision: revision, slots: 2),
                TransitionPeople.profile(TransitionPeople.taylor, name: "Taylor", revision: revision),
            ]
            return DiscoveryFeed(state: .ready, visible: true, candidates: Array(profiles.dropFirst(index)))
        }
        func setVisible(_ visible: Bool) -> DiscoveryFeed { load() }
        func block(_ profileID: UUID) -> DiscoveryFeed { load() }
        func decide(on profileID: UUID, choice: ConnectionChoice) async throws -> DiscoveryFeed {
            isSaving = true
            defer { isSaving = false }
            await withCheckedContinuation { response = $0 }
            if fails {
                fails = false
                throw AuthorizedPhotoError.unavailable
            }
            index += 1
            revision += 1  // Every acknowledgement renews all remaining signatures.
            return load()
        }
        func finish() {
            response?.resume()
            response = nil
        }
    }

    @MainActor @Observable private final class TransitionPhotoProbe {
        private var downloads: [String: Int] = [:]
        func count(owner: UUID, slot: Int) -> Int {
            downloads["\(owner)/\(slot == 1 ? "profile.jpg" : "profile-\(slot).jpg")", default: 0]
        }
        func download(_ url: URL) async throws -> Data {
            try await Task.sleep(for: .milliseconds(150))
            let owner = url.deletingLastPathComponent().lastPathComponent
            downloads["\(owner)/\(url.lastPathComponent)", default: 0] += 1
            let color: UIColor = owner == TransitionPeople.alex.uuidString ? .systemGreen : .systemBlue
            return UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
                color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            }.jpegData(compressionQuality: 0.8)!
        }
    }
#endif
