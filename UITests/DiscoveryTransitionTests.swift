import UIKit
import XCTest

final class DiscoveryTransitionTests: XCTestCase {
    @MainActor func testFailedDecisionClearsFeedbackAndOffersRecovery() {
        let app = launch(["--ui-test-decision-fails"])
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 8))
        app.buttons["discovery.pass"].tap()
        XCTAssertTrue(app.buttons["Finish decision"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["discovery.pass"].value as? String, "Saving decision")
        XCTAssertTrue(app.staticTexts["Alex"].exists)
        app.buttons["Finish decision"].tap()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Sam"].exists)
        XCTAssertFalse(app.buttons["discovery.pass"].exists)
        app.buttons["Try again"].tap()
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["discovery.pass"].value as? String, "")
        XCTAssertTrue(app.buttons["discovery.pass"].isEnabled)
    }

    @MainActor func testDecisionWaitsForServerAndReusesOnlyTheNextMainPhoto() {
        let app = launch([])
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 8))
        waitForLabel("Sam main downloads: 1", element: app.staticTexts["fixture.samDownloads"])
        XCTAssertEqual(app.staticTexts["fixture.samExtraDownloads"].label, "Sam extra downloads: 0")
        XCTAssertEqual(app.staticTexts["fixture.taylorDownloads"].label, "Taylor downloads: 0")
        let connect = app.buttons["discovery.connect"]
        connect.tap()
        XCTAssertTrue(app.buttons["Finish decision"].waitForExistence(timeout: 5))
        XCTAssertEqual(connect.value as? String, "Saving decision")
        XCTAssertFalse(connect.isEnabled)
        XCTAssertFalse(app.buttons["discovery.pass"].isEnabled)
        XCTAssertTrue(app.staticTexts["Alex"].exists)
        XCTAssertFalse(app.staticTexts["Sam"].exists)
        app.buttons["Finish decision"].tap()
        XCTAssertTrue(app.staticTexts["Sam"].waitForExistence(timeout: 5))
        waitForLabel("Taylor downloads: 1", element: app.staticTexts["fixture.taylorDownloads"])
        waitForLabel("Sam extra downloads: 1", element: app.staticTexts["fixture.samExtraDownloads"])
        XCTAssertEqual(
            app.staticTexts["fixture.samDownloads"].label, "Sam main downloads: 1",
            "A renewed signature must reuse the still-valid preload")
        XCTAssertTrue(app.images["photo.loaded"].firstMatch.exists)
        XCTAssertEqual(app.buttons["photos.gallery"].value as? String, "1 of 2")
        XCTAssertTrue(app.buttons["discovery.connect"].isEnabled)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Next card after decision"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testConsecutiveConnectAndPassKeepTheCardAndControlsStable() {
        let app = launch(["--ui-test-fast-decisions"])
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 8))
        let gallery = app.buttons["photos.gallery"]
        let originalFrame = gallery.frame
        for (choice, nextName, previousName) in [("connect", "Sam", "Alex"), ("pass", "Taylor", "Sam")] {
            app.buttons["discovery.\(choice)"].tap()
            XCTAssertTrue(app.staticTexts[nextName].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts[previousName].exists)
            XCTAssertEqual(app.buttons.matching(identifier: "discovery.connect").count, 1)
            XCTAssertEqual(gallery.frame.minY, originalFrame.minY, accuracy: 1)
            XCTAssertEqual(gallery.frame.width, originalFrame.width, accuracy: 1)
            XCTAssertEqual(gallery.frame.height, originalFrame.height, accuracy: 1)
            assertBlueFixturePhoto(in: gallery)
            XCTAssertTrue(app.buttons["discovery.connect"].isEnabled)
            XCTAssertTrue(app.buttons["discovery.pass"].isEnabled)
        }
        app.buttons["discovery.pass"].tap()
        XCTAssertTrue(app.staticTexts["You’re caught up."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["discovery.connect"].exists)
    }

    @MainActor private func assertBlueFixturePhoto(in gallery: XCUIElement) {
        guard let image = gallery.screenshot().image.cgImage,
            let center = image.cropping(
                to: CGRect(x: image.width / 2, y: image.height / 2, width: 1, height: 1))
        else {
            XCTFail("Photo pixels unavailable")
            return
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            )
            context?.draw(center, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        XCTAssertGreaterThan(
            Int(pixel[2]) - Int(pixel[0]), 100, "The next photo must render, not a blank frame")
    }

    @MainActor private func waitForLabel(_ label: String, element: XCUIElement) {
        let expected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed)
    }

    @MainActor private func launch(_ flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-discovery-transitions"] + flags
        app.launch()
        return app
    }
}
