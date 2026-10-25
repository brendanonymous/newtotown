#if DEBUG
    import NewToTownCore
    import UIKit

    @MainActor enum LayoutJourneyServices {
        static func photos(saved: Bool) -> any PhotoService {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
                UIColor.systemGreen.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            }
            return PhotoFixture(profile: saved ? image.jpegData(compressionQuality: 0.8) : nil)
        }

        @MainActor private final class PhotoFixture: PhotoService {
            var stored: PrivatePhotos
            init(profile: Data?) { stored = PrivatePhotos(profile: profile) }
            func requirements() -> PhotoRequirements { PhotoRequirements(reviewRequired: false) }
            func loadProfilePhoto() -> Data? { stored.profile }
            func load() -> PrivatePhotos { stored }
            func save(_ photos: PrivatePhotos) { stored = photos }
            func remove() { stored = PrivatePhotos() }
        }
    }
#endif
