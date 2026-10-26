import Foundation
import ImageIO

enum ProfileImageDecodingError: Error { case invalidData }

/// CGImage is immutable, so a decoded bitmap can safely cross actor boundaries.
struct ProfileImagePixels: @unchecked Sendable { let cgImage: CGImage }

enum ProfileImageDecoder {
    static func pixels(for size: CGSize, scale: CGFloat) -> Int {
        Int(min(1200, max(1, max(size.width, size.height) * scale)))
    }

    /// Decode only the pixels needed by the view, rather than a full-size bitmap.
    static func decode(_ data: Data, pixels: Int) throws -> ProfileImagePixels {
        guard pixels > 0,
            let source = CGImageSourceCreateWithData(
                data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: min(1200, pixels),
                ] as CFDictionary)
        else { throw ProfileImageDecodingError.invalidData }
        return ProfileImagePixels(cgImage: image)
    }
}
