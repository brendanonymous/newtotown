import XCTest

final class InterestJourneyTests: XCTestCase {
    @MainActor
    func testProfileInterestsPersistAndDiscoveryFiltersAreSeparate() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-messaging"]
        app.launch()
        ProfileEditorNavigation.open(.interests, in: app)
        let sports = app.buttons["interests.category.sports_fitness"]
        XCTAssertTrue(sports.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["interest.golf"].exists)
        sports.tap()
        for id in ["golf", "pickleball", "gym"] {
            let choice = app.buttons["interest.\(id)"]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
        }
        XCTAssertFalse(app.buttons["interest.running"].isEnabled)
        XCTAssertTrue(app.buttons["interest.golf"].isEnabled)
        sports.tap()
        XCTAssertFalse(app.buttons["interest.golf"].exists)
        XCTAssertTrue(sports.label.contains("Golf"))
        let save = app.buttons["interests.save"]
        reach(save, in: app)
        save.tap()
        ProfileEditorNavigation.closeMenu(in: app)
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Golf"].waitForExistence(timeout: 5))
        app.buttons["profile.preferences"].tap()
        app.buttons["preferences.interests"].tap()
        XCTAssertTrue(sports.waitForExistence(timeout: 5))
        sports.tap()
        let golf = app.buttons["interest.golf"]
        XCTAssertTrue(golf.waitForExistence(timeout: 5))
        XCTAssertEqual(golf.value as? String, "Not selected")
        golf.tap()
        reach(save, in: app)
        save.tap()
        XCTAssertTrue(app.buttons["preferences.interests"].waitForExistence(timeout: 5))
        app.buttons["preferences.interests"].tap()
        XCTAssertTrue(sports.waitForExistence(timeout: 5))
        sports.tap()
        XCTAssertTrue(golf.waitForExistence(timeout: 5))
        XCTAssertEqual(golf.value as? String, "Selected")
        golf.tap()
        reach(save, in: app)
        save.tap()
        XCTAssertTrue(app.buttons["preferences.interests"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNewProfilePromptsForInterestsAndSavesBeforeOpeningHome() {
        let app = newProfileApp()
        app.buttons["Save my profile"].tap()
        let sports = app.buttons["interests.category.sports_fitness"]
        XCTAssertTrue(sports.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["profile.edit"].exists)
        sports.tap()
        let swimming = app.buttons["interest.swimming"]
        reach(swimming, in: app)
        swimming.tap()
        for _ in 0..<6 {
            if sports.isHittable { break }
            app.swipeDown()
        }
        sports.tap()
        let next = app.buttons["interests.save"]
        reach(next, in: app)
        next.tap()
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Swimming"].exists)
    }

    @MainActor
    func testNewProfileCanSkipOptionalInterests() {
        let app = newProfileApp()
        app.buttons["Save my profile"].tap()
        let skip = app.buttons["interests.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        reach(skip, in: app)
        skip.tap()
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testFailedSignupInterestSaveKeepsSelectionAndRetries() {
        let app = newProfileApp(arguments: ["--ui-test-interest-save-fails"])
        app.buttons["Save my profile"].tap()
        let sports = app.buttons["interests.category.sports_fitness"]
        XCTAssertTrue(sports.waitForExistence(timeout: 10))
        sports.tap()
        app.buttons["interest.golf"].tap()
        sports.tap()
        let next = app.buttons["interests.save"]
        reach(next, in: app)
        next.tap()
        XCTAssertTrue(
            app.staticTexts["We couldn’t load or save your interests. Please try again."].waitForExistence(
                timeout: 5))
        XCTAssertFalse(app.buttons["profile.edit"].exists)
        sports.tap()
        XCTAssertEqual(app.buttons["interest.golf"].value as? String, "Selected")
        sports.tap()
        reach(next, in: app)
        next.tap()
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 10))
    }

    @MainActor private func newProfileApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-messaging", "--ui-test-new-profile"] + arguments
        app.launch()
        let save = app.buttons["Save my profile"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        reach(save, in: app)
        return app
    }

    @MainActor private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
