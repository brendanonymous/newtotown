import SwiftUI

/// Prepare only the current card's photos together. Taps change visibility without
/// resizing the frame, starting another download, or extending authorization.
struct ProfilePhotoGallery<Photo: View>: View {
    let count: Int
    var selection: Binding<Int>? = nil
    @ViewBuilder let photo: (Int) -> Photo
    @State private var index = 0

    private var current: Int { min(max(0, selection?.wrappedValue ?? index), max(0, count - 1)) }

    private func select(_ value: Int) {
        if let selection { selection.wrappedValue = value } else { index = value }
    }

    var body: some View {
        if count > 0 {
            VStack(spacing: 8) {
                ProfilePhotoFrame {
                    GeometryReader { geometry in
                        Button {
                            select((current + 1) % count)
                        } label: {
                            ZStack {
                                ForEach(0..<count, id: \.self) { photoIndex in
                                    photo(photoIndex)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .clipped()
                                        .opacity(photoIndex == current ? 1 : 0)
                                        .accessibilityHidden(photoIndex != current)
                                        .allowsHitTesting(false)
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .contentShape(Rectangle())
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Profile photos")
                        .accessibilityValue("\(current + 1) of \(count)")
                        .accessibilityHint(count > 1 ? "Tap for the next photo." : "")
                        .accessibilityIdentifier("photos.gallery")
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment: select((current + 1) % count)
                            case .decrement: select((current + count - 1) % count)
                            @unknown default: break
                            }
                        }
                    }
                }
                HStack(spacing: 4) {
                    ForEach(0..<count, id: \.self) { dot in
                        Circle()
                            .fill(dot == current ? BrandTheme.ink : BrandTheme.ink.opacity(0.22))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
            .onChange(of: count) { _, _ in select(0) }
        }
    }
}
