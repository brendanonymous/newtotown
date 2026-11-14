import SwiftUI

private struct ProfileImageStoreKey: EnvironmentKey {
    static let defaultValue: ProfileImageStore? = nil
}

extension EnvironmentValues {
    var profileImages: ProfileImageStore? {
        get { self[ProfileImageStoreKey.self] }
        set { self[ProfileImageStoreKey.self] = newValue }
    }
}

/// Shared avatar/card loader; the surrounding view supplies the photo shape and shadow.
struct RemoteProfilePhoto: View {
    let url: URL
    var isAvatar = false
    @Environment(\.profileImages) private var images
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var failed = false
    private struct Request: Hashable {
        let url: URL
        let pixels: Int
    }

    var body: some View {
        GeometryReader { geometry in
            let pixels = ProfileImageDecoder.pixels(for: geometry.size, scale: displayScale)
            Group {
                if let image = image ?? images?.cachedImage(for: url, pixels: pixels) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .accessibilityLabel("Profile photo").accessibilityIdentifier("photo.loaded")
                } else if isAvatar {
                    Image(systemName: "person.crop.square").foregroundStyle(BrandTheme.secondaryInk)
                } else if failed {
                    Label("Photo unavailable. Pull down to try again.", systemImage: "photo")
                        .font(.callout).padding()
                } else {
                    ProgressView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .task(id: Request(url: url, pixels: pixels)) {
                image = nil
                failed = false
                guard let images else {
                    failed = true
                    return
                }
                do {
                    let loaded = try await images.image(for: url, pixels: pixels)
                    guard !Task.isCancelled else { return }
                    image = loaded
                } catch {
                    guard !Task.isCancelled else { return }
                    failed = true
                }
            }
        }
    }
}
