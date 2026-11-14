#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Export the supplied 8192-pixel PNG masters; the traced SVG is for future design edits.
// Keep source artwork out of the app bundle and decode only the output's needed pixels.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceDirectory = root.appendingPathComponent("Design/Brand")
let assets = root.appendingPathComponent("App/Assets.xcassets")
let outputSize = 1024

func export(_ filename: String, opaque: Bool, to path: String) {
    guard
        let source = CGImageSourceCreateWithURL(
            sourceDirectory.appendingPathComponent(filename) as CFURL, nil),
        let image = CGImageSourceCreateThumbnailAtIndex(
            source, 0,
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: outputSize,
            ] as CFDictionary)
    else { fatalError("Could not load supplied asset: \(filename)") }

    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    guard
        let bitmap = CGContext(
            data: nil, width: outputSize, height: outputSize, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: alpha.rawValue)
    else { fatalError("Could not prepare brand bitmap") }
    let bounds = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
    bitmap.clear(bounds)
    if opaque {
        bitmap.setFillColor(CGColor(red: 181 / 255, green: 190 / 255, blue: 166 / 255, alpha: 1))
        bitmap.fill(bounds)
    }
    bitmap.interpolationQuality = .high
    bitmap.draw(image, in: bounds)
    guard let result = bitmap.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            assets.appendingPathComponent(path) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("Could not create brand output") }
    CGImageDestinationAddImage(destination, result, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not save brand output") }
}

export("NewToTown_iOS_Square_8192px.png", opaque: true, to: "AppIcon.appiconset/AppIcon.png")
export("NewToTown_Rounded_Transparent_8192px.png", opaque: false, to: "BrandLogo.imageset/BrandLogo.png")
print("Exported the corrected app icon and rounded logo from the supplied 8192-pixel PNG masters.")
