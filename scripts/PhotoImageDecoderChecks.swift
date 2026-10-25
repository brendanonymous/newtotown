import CoreGraphics
import Foundation
import ImageIO

/// Runs against the actual app decoder on the macOS CI runner, without a simulator.
@main struct PhotoImageDecoderChecks {
    static func main() throws {
        let context = CGContext(
            data: nil, width: 1200, height: 800, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.5, green: 0.6, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
        let avatar = try ProfileImageDecoder.decode(data as Data, pixels: 144)
        precondition(avatar.cgImage.width == 144 && avatar.cgImage.height == 96)
        precondition(avatar.cgImage.bytesPerRow * avatar.cgImage.height < 128 * 1024)
        let card = try ProfileImageDecoder.decode(data as Data, pixels: 900)
        precondition(card.cgImage.width == 900 && card.cgImage.height == 600)
        do {
            _ = try ProfileImageDecoder.decode(Data([0, 1, 2]), pixels: 144)
            preconditionFailure("Invalid image bytes were accepted")
        } catch ProfileImageDecodingError.invalidData {}
        do {
            _ = try ProfileImageDecoder.decode(data as Data, pixels: 0)
            preconditionFailure("Invalid pixel size was accepted")
        } catch ProfileImageDecodingError.invalidData {}
        print("Photo decoder checks passed: avatar/card sizes, memory cost, and invalid input.")
    }
}
