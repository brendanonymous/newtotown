import ImageIO
import NewToTownCore
import UIKit

/// Downsample before decoding and re-encode pixels only, omitting source EXIF/GPS.
enum PhotoImageEncoder {
    static func jpeg(from data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1200
              ] as CFDictionary) else { throw PhotoValidationError.invalidImage }
        return try jpeg(from: UIImage(cgImage: image))
    }

    static func jpeg(from image: UIImage) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else { throw PhotoValidationError.invalidImage }
        let scale = min(1, 1200 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = normalized.jpegData(compressionQuality: 0.8),
              data.count <= PrivatePhotos.maximumFileSize else { throw PhotoValidationError.tooLarge }
        return data
    }
}
