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
    func testEmptyPhotoEditorShowsOnlyChooseAction() {
        let app = launch(["--ui-test-photos"])
        ProfileEditorNavigation.open(.photos, in: app)
        XCTAssertTrue(app.buttons["photos.choose"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["photos.save"].exists)
        XCTAssertFalse(app.buttons["photos.remove"].exists)
        XCTAssertFalse(app.staticTexts["Profile photo"].exists)
        XCTAssertFalse(app.staticTexts["No photo yet"].exists)
    }

    @MainActor
    func testEmptyPhotoFrameOpensPhotosDirectlyAndReturnsHome() {
        let app = launch(["--ui-test-photos"])
        let addPhoto = app.buttons["profile.addPhoto"]
        XCTAssertTrue(addPhoto.waitForExistence(timeout: 10))
        addPhoto.tap()
        assertDirectPhotoEditorGoesBackHome(in: app)

        // The empty frame around the label is also a generous tap target.
        addPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        assertDirectPhotoEditorGoesBackHome(in: app)
    }

    @MainActor
    func testStoredPhotoCanBeRemovedWithoutShowingUnneededSave() {
        let app = launch(["--ui-test-photos", "--ui-test-saved-photo", "--ui-test-slow-photo-reload"])
        XCTAssertTrue(app.buttons["photos.gallery"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["profile.addPhoto"].exists)
        ProfileEditorNavigation.open(.photos, in: app)
        XCTAssertTrue(app.buttons["photos.removeOne"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["photos.save"].exists)
        app.buttons["photos.removeOne"].tap()
        XCTAssertTrue(app.buttons["photos.choose"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertFalse(app.buttons["photos.removeOne"].exists)
        XCTAssertFalse(app.buttons["photos.remove"].exists)
        ProfileEditorNavigation.backToMenu(in: app)
        ProfileEditorNavigation.closeMenu(in: app)
        XCTAssertTrue(app.buttons["profile.addPhoto"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["photos.gallery"].exists)
        app.buttons["profile.addPhoto"].tap()
        assertDirectPhotoEditorGoesBackHome(in: app)
    }

    @MainActor
    func testDiscoveryDecisionColumnDoesNotOverlapLongProfileText() {
        let app = launch(["--ui-test-discovery-layout", "--ui-test-profile-images"])
        app.tabBars.buttons["Discovery"].tap()
        let connect = app.buttons["discovery.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Block this profile"].exists)
        let pass = app.buttons["discovery.pass"]
        let details = app.staticTexts.matching(identifier: "profile.details").allElementsBoundByIndex
        XCTAssertFalse(details.isEmpty)
        for detail in details { XCTAssertLessThanOrEqual(detail.frame.maxX, connect.frame.minX) }
        XCTAssertEqual(connect.frame.minX, pass.frame.minX, accuracy: 1)
        XCTAssertEqual(connect.frame.width, 64, accuracy: 1)
        XCTAssertEqual(pass.frame.width, 64, accuracy: 1)
        XCTAssertEqual(pass.frame.minY - connect.frame.maxY, 18, accuracy: 1)
    }

    @MainActor private func assertDirectPhotoEditorGoesBackHome(in app: XCUIApplication) {
        XCTAssertFalse(app.sheets.firstMatch.exists, "The shortcut should push Photos onto the profile stack")
        XCTAssertTrue(app.buttons["photos.choose"].waitForExistence(timeout: 5))
        app.buttons["editor.back"].tap()
        XCTAssertTrue(app.buttons["profile.addPhoto"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profile.editor.close"].exists)
    }

    @MainActor private func launch(_ flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-messaging"] + flags
        app.launch()
        return app
    }
}
