import SwiftUI

/// Warm only the next candidate's main photo at the card's exact decode size.
/// The account-scoped store owns bounds, expiry, and shared in-flight requests.
struct DiscoveryPhotoPreloader: View {
    let url: URL?
    @Environment(\.profileImages) private var images
    @Environment(\.displayScale) private var displayScale

    private struct Request: Hashable {
        let url: URL?
        let pixels: Int
    }

    var body: some View {
        GeometryReader { geometry in
            let pixels = ProfileImageDecoder.pixels(
                for: CGSize(width: geometry.size.width, height: ProfilePhotoLayout.height),
                scale: displayScale)
            Color.clear
                .task(id: Request(url: url, pixels: pixels)) {
                    guard let url, let images else { return }
                    // Speculation must not surface errors or delay a decision.
                    _ = try? await images.image(for: url, pixels: pixels)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
