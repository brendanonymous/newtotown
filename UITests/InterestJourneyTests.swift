import XCTest

final class InterestJourneyTests: XCTestCase {
    @MainActor
    func testProfileInterestsPersistAndDiscoveryFiltersAreSeparate() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-messaging"]
        app.launch()
        let edit = app.buttons["profile.interests"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        reach(edit, in: app)
        edit.tap()
        for id in ["golf", "pickleball", "gym"] {
            let choice = app.buttons["interest.\(id)"]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
        }
        XCTAssertFalse(app.buttons["interest.running"].isEnabled)
        XCTAssertTrue(app.buttons["interest.golf"].isEnabled)
        let save = app.buttons["interests.save"]
        reach(save, in: app)
        save.tap()
        XCTAssertTrue(app.buttons["profile.interests"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Golf"].waitForExistence(timeout: 5))
        app.buttons["profile.preferences"].tap()
        app.buttons["preferences.interests"].tap()
        let golf = app.buttons["interest.golf"]
        XCTAssertTrue(golf.waitForExistence(timeout: 5))
        XCTAssertEqual(golf.value as? String, "Not selected")
        golf.tap()
        reach(save, in: app)
        save.tap()
        XCTAssertTrue(app.buttons["preferences.interests"].waitForExistence(timeout: 5))
        app.buttons["preferences.interests"].tap()
        XCTAssertTrue(golf.waitForExistence(timeout: 5))
        XCTAssertEqual(golf.value as? String, "Selected")
        golf.tap()
        reach(save, in: app)
        save.tap()
        XCTAssertTrue(app.buttons["preferences.interests"].waitForExistence(timeout: 5))
    }

    @MainActor private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
