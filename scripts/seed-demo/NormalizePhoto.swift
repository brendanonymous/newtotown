import Foundation
import ImageIO
import UniformTypeIdentifiers

// Match the app's upload limit and omit original EXIF/GPS metadata.
guard CommandLine.arguments.count == 3,
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
    let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 1200,
        kCGImageSourceShouldCacheImmediately: true,
    ] as CFDictionary),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL,
        UTType.jpeg.identifier as CFString, 1, nil)
else {
    fputs("Could not decode or prepare demo portrait.\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(destination, image, [
    kCGImageDestinationLossyCompressionQuality: 0.8
] as CFDictionary)
guard CGImageDestinationFinalize(destination) else { exit(1) }
