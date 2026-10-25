#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// The approved, unmodified raster source also supplies the in-app BrandLogo asset.
// Center-crop background at the sides for a square icon; never stretch the mark.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("App/Assets.xcassets")
let sourceURL = assets.appendingPathComponent("BrandLogo.imageset/BrandLogo.png")
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
    let original = CGImageSourceCreateImageAtIndex(source, 0, nil)
else { fatalError("Could not read the approved BrandLogo.png source") }

let side = min(original.width, original.height)
let crop = CGRect(
    x: (original.width - side) / 2,
    y: (original.height - side) / 2,
    width: side, height: side)
guard let square = original.cropping(to: crop),
    let bitmap = CGContext(
        data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("Could not prepare the square app icon") }

// iOS app icons are opaque. This backing color is only visible through source alpha.
bitmap.setFillColor(CGColor(red: 0.75, green: 0.78, blue: 0.68, alpha: 1))
bitmap.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
bitmap.interpolationQuality = .high
bitmap.draw(square, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let output = assets.appendingPathComponent("AppIcon.appiconset/AppIcon.png")
guard let image = bitmap.makeImage(),
    let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("Could not create the app icon output") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not save the app icon") }
print("Exported opaque 1024 × 1024 icon from the approved artwork.")
