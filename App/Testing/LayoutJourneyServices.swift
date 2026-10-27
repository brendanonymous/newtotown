#if DEBUG
    import NewToTownCore
    import UIKit

    @MainActor enum LayoutJourneyServices {
        static func photos(saved: Bool) -> any PhotoService {
            let additional =
                saved && ProcessInfo.processInfo.arguments.contains("--ui-test-photo-gallery")
                ? [jpeg(color: .systemBlue), jpeg(color: .systemOrange)] : []
            return PhotoFixture(profile: saved ? jpeg(color: .systemGreen) : nil, additional: additional)
        }

        private static func jpeg(color: UIColor) -> Data {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
                color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            }
            return image.jpegData(compressionQuality: 0.8)!
        }

        @MainActor private final class PhotoFixture: PhotoService {
            var stored: PrivatePhotos
            private var ownerReads = 0
            init(profile: Data?, additional: [Data]) {
                stored = PrivatePhotos(profile: profile, additionalProfiles: additional)
            }
            func requirements() -> PhotoRequirements { PhotoRequirements(reviewRequired: false) }
            func loadProfilePhotos() async throws -> [Data] {
                ownerReads += 1
                if ownerReads > 1 && ProcessInfo.processInfo.arguments.contains("--ui-test-slow-photo-reload")
                {
                    try await Task.sleep(for: .seconds(30))
                }
                return stored.profilePhotos
            }
            func load() -> PrivatePhotos { stored }
            func save(_ photos: PrivatePhotos) { stored = photos }
            func remove() { stored = PrivatePhotos() }
        }
    }
#endif
