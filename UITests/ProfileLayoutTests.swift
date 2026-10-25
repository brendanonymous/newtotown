import XCTest

final class ProfileLayoutTests: XCTestCase {
    @MainActor
    func testStartupHasOneLoadingIndicator() {
        let app = launch(["--ui-test-loading"])
        XCTAssertTrue(app.activityIndicators.firstMatch.waitForExistence(timeout: 5))
        // SwiftUI exposes a wrapper and its UIKit indicator at the same position.
        let indicators = app.activityIndicators.allElementsBoundByIndex
        XCTAssertEqual(Set(indicators.map { String(describing: $0.frame) }).count, 1)
    }

    @MainActor
    func testEmptyPhotoSheetShowsOnlyChooseAction() {
        let app = launch(["--ui-test-photos"])
        XCTAssertTrue(app.buttons["My photos"].waitForExistence(timeout: 10))
        app.buttons["My photos"].tap()
        XCTAssertTrue(app.buttons["photos.choose"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["photos.save"].exists)
        XCTAssertFalse(app.buttons["photos.remove"].exists)
        XCTAssertFalse(app.staticTexts["Profile photo"].exists)
        XCTAssertFalse(app.staticTexts["No photo yet"].exists)
    }

    @MainActor
    func testStoredPhotoCanBeRemovedWithoutShowingUnneededSave() {
        let app = launch(["--ui-test-photos", "--ui-test-saved-photo"])
        XCTAssertTrue(app.buttons["My photos"].waitForExistence(timeout: 10))
        app.buttons["My photos"].tap()
        XCTAssertTrue(app.buttons["photos.remove"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["photos.save"].exists)
        app.buttons["photos.remove"].tap()
        app.alerts.buttons["Remove photos"].tap()
        XCTAssertTrue(app.buttons["photos.choose"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["photos.remove"].exists)
    }

    @MainActor
    func testDiscoveryDecisionColumnDoesNotOverlapLongProfileText() {
        let app = launch(["--ui-test-discovery-layout", "--ui-test-profile-images"])
        app.tabBars.buttons["Discovery"].tap()
        let connect = app.buttons["discovery.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 10))
        let pass = app.buttons["discovery.pass"]
        let details = app.staticTexts.matching(identifier: "profile.details").allElementsBoundByIndex
        XCTAssertFalse(details.isEmpty)
        for detail in details { XCTAssertLessThanOrEqual(detail.frame.maxX, connect.frame.minX) }
        XCTAssertEqual(connect.frame.minX, pass.frame.minX, accuracy: 1)
        XCTAssertGreaterThan(pass.frame.minY, connect.frame.maxY)
    }

    @MainActor private func launch(_ flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-messaging"] + flags
        app.launch()
        return app
    }
}
