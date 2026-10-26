import CoreGraphics
import Foundation

/// Converts a zoomed, panned viewport into source-image coordinates without
/// stretching the image or allowing the exported crop beyond its edges.
public enum PhotoCropGeometry {
    public static func sourceRect(
        image: CGSize, viewport: CGSize, zoom: CGFloat, offset: CGPoint
    ) -> CGRect? {
        let values = [image.width, image.height, viewport.width, viewport.height, zoom, offset.x, offset.y]
        guard values.allSatisfy(\.isFinite),
            image.width > 0, image.height > 0, viewport.width > 0, viewport.height > 0,
            zoom + 0.000001 >= max(viewport.width / image.width, viewport.height / image.height)
        else { return nil }
        let width = min(image.width, viewport.width / zoom)
        let height = min(image.height, viewport.height / zoom)
        let x: CGFloat = min(max(CGFloat.zero, offset.x / zoom), image.width - width)
        let y: CGFloat = min(max(CGFloat.zero, offset.y / zoom), image.height - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
