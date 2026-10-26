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
