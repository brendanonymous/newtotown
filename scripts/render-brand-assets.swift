#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Reuse the supplied production master and transparent lettermark; never redraw the glyph.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("Design/Brand")
let assets = root.appendingPathComponent("App/Assets.xcassets")

func image(_ filename: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(source.appendingPathComponent(filename) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fatalError("Could not load approved asset: \(filename)") }
    return image
}

func export(_ image: CGImage, background: CGColor, grayscale: Bool = false, to path: String) {
    let space = grayscale ? CGColorSpaceCreateDeviceGray() : CGColorSpace(name: CGColorSpace.sRGB)!
    let alpha: CGImageAlphaInfo = grayscale ? .none : .noneSkipLast
    guard
        let bitmap = CGContext(
            data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: alpha.rawValue)
    else { fatalError("Could not prepare icon bitmap") }
    bitmap.setFillColor(background)
    bitmap.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    bitmap.interpolationQuality = .high
    bitmap.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    guard let result = bitmap.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            assets.appendingPathComponent(path) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("Could not create icon output") }
    CGImageDestinationAddImage(destination, result, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not save icon") }
}

let master = image("NewToTown_AppIcon_4096.png")
let letter = image("NewToTown_N_Transparent_4096.png")
let sage = CGColor(red: 168 / 255, green: 173 / 255, blue: 143 / 255, alpha: 1)
let ink = CGColor(red: 41 / 255, green: 59 / 255, blue: 48 / 255, alpha: 1)
export(master, background: sage, to: "AppIcon.appiconset/AppIcon.png")
export(letter, background: ink, to: "AppIcon.appiconset/AppIcon-dark.png")
export(
    letter, background: CGColor(gray: 0, alpha: 1), grayscale: true,
    to: "AppIcon.appiconset/AppIcon-tinted.png")
try FileManager.default.copyItemReplacing(
    at: assets.appendingPathComponent("AppIcon.appiconset/AppIcon.png"),
    to: assets.appendingPathComponent("BrandLogo.imageset/BrandLogo.png"))
try FileManager.default.copyItemReplacing(
    at: assets.appendingPathComponent("AppIcon.appiconset/AppIcon-dark.png"),
    to: assets.appendingPathComponent("BrandLogo.imageset/BrandLogo-dark.png"))
print("Exported default, dark and tinted icons from the supplied 4096-pixel assets.")

extension FileManager {
    func copyItemReplacing(at source: URL, to destination: URL) throws {
        if fileExists(atPath: destination.path) { try removeItem(at: destination) }
        try copyItem(at: source, to: destination)
    }
}
