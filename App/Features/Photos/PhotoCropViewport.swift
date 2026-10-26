import NewToTownCore
import SwiftUI
import UIKit

/// UIScrollView provides familiar pinch-to-zoom and constrained panning.
@MainActor final class PhotoCropController {
    weak var viewport: PhotoCropScrollView?

    func jpeg() throws -> Data {
        guard let viewport, let image = viewport.imageView.image,
            let rect = PhotoCropGeometry.sourceRect(
                image: image.size, viewport: viewport.bounds.size,
                zoom: viewport.zoomScale, offset: viewport.contentOffset)
        else { throw PhotoValidationError.invalidImage }
        let scale = min(1, 1200 / max(rect.width, rect.height))
        let size = CGSize(width: rect.width * scale, height: rect.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let cropped = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(
                in: CGRect(
                    x: -rect.minX * scale, y: -rect.minY * scale,
                    width: image.size.width * scale, height: image.size.height * scale))
        }
        return try PhotoImageEncoder.jpeg(from: cropped)
    }
}

struct PhotoCropViewport: UIViewRepresentable {
    let image: UIImage
    let controller: PhotoCropController

    func makeUIView(context: Context) -> PhotoCropScrollView {
        let view = PhotoCropScrollView(image: image)
        controller.viewport = view
        return view
    }

    func updateUIView(_ uiView: PhotoCropScrollView, context: Context) {}
}

final class PhotoCropScrollView: UIScrollView, UIScrollViewDelegate {
    let imageView: UIImageView
    private var viewportSize = CGSize.zero

    init(image: UIImage) {
        imageView = UIImageView(image: image)
        super.init(frame: .zero)
        delegate = self
        bounces = false
        bouncesZoom = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        imageView.frame = CGRect(origin: .zero, size: image.size)
        addSubview(imageView)
        contentSize = image.size
        accessibilityLabel = "Photo crop. Pinch to zoom and drag to position your photo."
        accessibilityIdentifier = "photos.crop.viewport"
    }

    required init?(coder: NSCoder) { fatalError("Use init(image:)") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, bounds.size != viewportSize,
            let image = imageView.image
        else { return }
        viewportSize = bounds.size
        let cover = max(bounds.width / image.size.width, bounds.height / image.size.height)
        minimumZoomScale = cover
        maximumZoomScale = cover * 4
        zoomScale = cover
        contentOffset = CGPoint(
            x: max(0, (image.size.width * cover - bounds.width) / 2),
            y: max(0, (image.size.height * cover - bounds.height) / 2))
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
}
