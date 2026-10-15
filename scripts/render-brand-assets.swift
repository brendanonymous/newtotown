#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// Vector reconstruction of the supplied sage/ivory monogram. Keep source paths
// here so the toolbar logo and opaque, unmasked iOS icon use the same artwork.
let monogram = CGMutablePath()
let points: [CGPoint] = [
    .init(x: 174, y: 182), .init(x: 326, y: 182),
    .init(x: 678, y: 642), .init(x: 678, y: 238),
    .init(x: 620, y: 238), .init(x: 620, y: 182),
    .init(x: 820, y: 182), .init(x: 820, y: 238),
    .init(x: 762, y: 238), .init(x: 762, y: 836),
    .init(x: 678, y: 836), .init(x: 292, y: 330),
    .init(x: 292, y: 780), .init(x: 350, y: 780),
    .init(x: 350, y: 836), .init(x: 174, y: 836),
    .init(x: 174, y: 780), .init(x: 230, y: 780),
    .init(x: 230, y: 238), .init(x: 174, y: 238)
]
monogram.addLines(between: points)
monogram.closeSubpath()
let colorSpace = CGColorSpaceCreateDeviceRGB()
let sage = CGColor(colorSpace: colorSpace, components: [0.75, 0.78, 0.68, 1])!
let ivory = CGColor(colorSpace: colorSpace, components: [0.98, 0.97, 0.95, 1])!

func draw(in context: CGContext, size: CGFloat) {
    context.saveGState()
    context.scaleBy(x: size / 1024, y: size / 1024)
    context.setFillColor(sage)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)
    context.setFillColor(ivory)
    context.addPath(monogram)
    context.fillPath()
    context.restoreGState()
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("App/Assets.xcassets")
let bitmap = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
draw(in: bitmap, size: 1024)
let png = NSBitmapImageRep(cgImage: bitmap.makeImage()!).representation(using: .png, properties: [:])!
try png.write(to: assets.appendingPathComponent("AppIcon.appiconset/AppIcon.png"))

var mediaBox = CGRect(x: 0, y: 0, width: 128, height: 128)
let pdfURL = assets.appendingPathComponent("BrandLogo.imageset/BrandLogo.pdf")
let pdf = CGContext(pdfURL as CFURL, mediaBox: &mediaBox, nil)!
pdf.beginPDFPage(nil)
draw(in: pdf, size: 128)
pdf.endPDFPage()
pdf.closePDF()
