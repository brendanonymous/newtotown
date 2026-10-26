import SwiftUI

/// Prepare the current card's photos together. Public cards advance on tap;
/// editors replace on tap and browse by swiping. Neither resizes the frame
/// or extends the photos' authorization.
struct ProfilePhotoGallery<Photo: View>: View {
    let count: Int
    var selection: Binding<Int>? = nil
    var onReplace: ((Int) -> Void)? = nil
    var onRemove: ((Int) -> Void)? = nil
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
                            if let onReplace { onReplace(current) } else { select((current + 1) % count) }
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
                        .accessibilityLabel(onReplace == nil ? "Profile photos" : "Replace photo")
                        .accessibilityValue("\(current + 1) of \(count)")
                        .accessibilityHint(
                            onReplace != nil
                                ? (count > 1
                                    ? "Tap to replace. Swipe left or right to browse photos."
                                    : "Tap to replace this photo.")
                                : (count > 1 ? "Tap for the next photo." : "")
                        )
                        .accessibilityIdentifier(onReplace == nil ? "photos.gallery" : "photos.editorGallery")
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment: select((current + 1) % count)
                            case .decrement: select((current + count - 1) % count)
                            @unknown default: break
                            }
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 20).onEnded { value in
                                guard onReplace != nil, count > 1,
                                    abs(value.translation.width) > 40,
                                    abs(value.translation.width) > abs(value.translation.height)
                                else { return }
                                select((current + (value.translation.width < 0 ? 1 : count - 1)) % count)
                            },
                            including: onReplace != nil && count > 1 ? .all : .none
                        )
                        .overlay(alignment: .topTrailing) {
                            if let onRemove {
                                Button(role: .destructive) {
                                    onRemove(current)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(BrandTheme.ink)
                                        .frame(width: 26, height: 26)
                                        .background(BrandTheme.background.opacity(0.94), in: Circle())
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(4)
                                .accessibilityLabel("Remove photo \(current + 1)")
                                .accessibilityIdentifier("photos.removeOne")
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
