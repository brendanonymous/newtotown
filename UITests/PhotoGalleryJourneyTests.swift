import UIKit
import XCTest

final class PhotoGalleryJourneyTests: XCTestCase {
    @MainActor func testOwnerCanCycleThreePhotosAndSaveRemovingOne() {
        let app = launch([
            "--ui-test-messaging", "--ui-test-photos", "--ui-test-saved-photo", "--ui-test-photo-gallery",
            "--ui-test-slow-photo-reload",
        ])
        let gallery = app.buttons["photos.gallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 10))
        XCTAssertEqual(gallery.value as? String, "1 of 3")
        XCTAssertEqual(gallery.frame.height, 300, accuracy: 1)
        capture(app, name: "Owner photo gallery")
        var previousPixels = centerPixels(gallery)
        for expected in ["2 of 3", "3 of 3", "1 of 3"] {
            gallery.tap()
            XCTAssertEqual(gallery.value as? String, expected)
            let pixels = centerPixels(gallery)
            XCTAssertNotEqual(
                pixels, previousPixels, "Tapping must change the displayed photo, not only the dots")
            previousPixels = pixels
        }
        app.buttons["My photos"].tap()
        let remove = app.buttons["photos.removeOne"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["photos.choose"].exists)
        XCTAssertFalse(app.buttons["photos.replace"].exists)
        XCTAssertFalse(app.buttons["photos.remove"].exists)
        let editorGallery = app.buttons["photos.editorGallery"]
        editorGallery.swipeLeft()
        XCTAssertEqual(editorGallery.value as? String, "2 of 3")
        XCTAssertTrue(editorGallery.isHittable, "Browsing must not open the replacement picker")
        capture(app, name: "My photos with corner removal")
        editorGallery.tap()
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(
            cancel.waitForExistence(timeout: 8), "Tapping a photo should open the replacement picker")
        cancel.tap()
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        XCTAssertEqual(editorGallery.value as? String, "2 of 3")
        XCTAssertGreaterThan(remove.frame.midX, editorGallery.frame.midX)
        XCTAssertLessThan(remove.frame.midY, editorGallery.frame.midY)
        remove.tap()
        XCTAssertTrue(app.buttons["photos.choose"].exists)
        capture(app, name: "Compact photo action buttons")
        app.buttons["photos.save"].tap()
        XCTAssertTrue(app.buttons["My photos"].waitForExistence(timeout: 5))
        XCTAssertEqual(gallery.value as? String, "1 of 2")
    }

    @MainActor func testDiscoveryGalleryCyclesWithoutChangingItsFrame() {
        let app = launch([
            "--ui-test-messaging", "--ui-test-discovery-layout", "--ui-test-photo-gallery",
            "--ui-test-profile-images",
        ])
        app.tabBars.buttons["Discovery"].tap()
        let gallery = app.buttons["photos.gallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 8))
        let original = gallery.frame
        XCTAssertEqual(original.height, 300, accuracy: 1)
        capture(app, name: "Discovery photo gallery")
        XCTAssertEqual(gallery.value as? String, "1 of 3")
        gallery.tap()
        XCTAssertEqual(gallery.value as? String, "2 of 3")
        XCTAssertEqual(gallery.frame, original)
        XCTAssertTrue(app.buttons["discovery.connect"].exists)
    }

    @MainActor func testCropCanBeCancelledThenZoomedAndExportedAtTheCardRatio() throws {
        let app = launch(["--ui-test-photo-crop"])
        app.buttons["Crop fixture photo"].tap()
        let viewport = app.scrollViews["photos.crop.viewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        app.buttons["editor.close"].tap()
        XCTAssertFalse(app.staticTexts["crop.ready"].exists)
        app.buttons["Crop fixture photo"].tap()
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        let ratio = viewport.frame.width / viewport.frame.height
        viewport.pinch(withScale: 2, velocity: 1)
        let start = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: end)
        capture(app, name: "Crop after zoom and pan")
        app.buttons["photos.crop.use"].tap()
        XCTAssertTrue(app.staticTexts["crop.ready"].waitForExistence(timeout: 5))
        let dimensions = app.staticTexts["crop.dimensions"].label.components(separatedBy: " × ")
        let width = try XCTUnwrap(Double(dimensions[0]))
        let height = try XCTUnwrap(Double(dimensions[1]))
        XCTAssertEqual(width / height, ratio, accuracy: 0.01)
        XCTAssertLessThanOrEqual(max(width, height), 1200)
    }

    @MainActor private func centerPixels(_ element: XCUIElement) -> Data? {
        guard let image = element.screenshot().image.cgImage,
            let crop = image.cropping(
                to: CGRect(x: image.width / 2 - 5, y: image.height / 2 - 5, width: 10, height: 10)),
            let data = crop.dataProvider?.data
        else {
            XCTFail("Photo pixels unavailable")
            return nil
        }
        return data as Data
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor private func launch(_ flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = flags
        app.launch()
        return app
    }
}
