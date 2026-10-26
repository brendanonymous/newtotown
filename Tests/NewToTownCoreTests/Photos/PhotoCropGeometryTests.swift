import CoreGraphics
import Foundation
import Testing

@testable import NewToTownCore

@Test func portraitCropCoversTheFrameAndClampsToImageEdges() throws {
    let rect = try #require(
        PhotoCropGeometry.sourceRect(
            image: CGSize(width: 800, height: 1200), viewport: CGSize(width: 400, height: 300),
            zoom: 0.5, offset: CGPoint(x: -100, y: 900)))
    #expect(rect == CGRect(x: 0, y: 600, width: 800, height: 600))
}

@Test func landscapeCropPreservesRatioWhileZoomingAndPanning() throws {
    let rect = try #require(
        PhotoCropGeometry.sourceRect(
            image: CGSize(width: 1200, height: 800), viewport: CGSize(width: 400, height: 300),
            zoom: 0.75, offset: CGPoint(x: 150, y: 75)))
    #expect(rect.minX == 200 && rect.minY == 100)
    #expect(abs(rect.width / rect.height - 4.0 / 3.0) < 0.0001)
    #expect(rect.maxX <= 1200 && rect.maxY <= 800)
}

@Test func invalidOrUnderfilledCropsCannotBeExported() {
    for zoom: CGFloat in [0, -1, 0.1, .nan, .infinity] {
        #expect(
            PhotoCropGeometry.sourceRect(
                image: CGSize(width: 800, height: 800), viewport: CGSize(width: 400, height: 300),
                zoom: zoom, offset: .zero) == nil)
    }
    #expect(PhotoCropGeometry.sourceRect(image: .zero, viewport: .zero, zoom: 1, offset: .zero) == nil)
}
