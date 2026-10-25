import CoreGraphics
import Foundation
import ImageIO

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let input = directory.appendingPathComponent("source.jpg")
let output = directory.appendingPathComponent("normalized.jpg")
let context = CGContext(
    data: nil, width: 2400, height: 1600, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(CGColor(red: 0.5, green: 0.6, blue: 0.4, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1600))
let destination = CGImageDestinationCreateWithURL(input as CFURL, "public.jpeg" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, [
    kCGImagePropertyOrientation: 6,
    kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "Private fixture comment"],
    kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 33.5, kCGImagePropertyGPSLatitudeRef: "N"],
] as CFDictionary)
precondition(CGImageDestinationFinalize(destination))

func normalize(_ source: URL) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
    process.arguments = [source.path, output.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}
let validStatus = try normalize(input)
precondition(validStatus == 0)
let source = CGImageSourceCreateWithURL(output as CFURL, nil)!
let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
precondition(properties[kCGImagePropertyPixelWidth] as? Int == 800)
precondition(properties[kCGImagePropertyPixelHeight] as? Int == 1200)
precondition(properties[kCGImagePropertyGPSDictionary] == nil)
let exif = properties[kCGImagePropertyExifDictionary] as? NSDictionary
precondition(exif?[kCGImagePropertyExifUserComment] == nil)
let normalizedData = try Data(contentsOf: output)
precondition(normalizedData.count < 3 * 1024 * 1024)
let invalid = directory.appendingPathComponent("invalid.jpg")
try Data([0, 1, 2]).write(to: invalid)
let invalidStatus = try normalize(invalid)
precondition(invalidStatus != 0)
print("Photo normalization passed: orientation, size, metadata removal, upload limit, invalid input.")
