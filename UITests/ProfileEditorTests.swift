import XCTest

final class ProfileEditorTests: XCTestCase {
    @MainActor func testSingleProfileEditorMenuOpensAndClosesEverySection() {
        let app = launch()
        XCTAssertEqual(app.buttons["profile.edit"].label, "Edit Profile")
        XCTAssertFalse(app.buttons["My photos"].exists)
        XCTAssertFalse(app.buttons["profile.interests"].exists)
        app.buttons["profile.edit"].tap()
        XCTAssertTrue(app.buttons["profile.editor.aboutMe"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Profile editor menu"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        ProfileEditorNavigation.open(.photos, in: app)
        XCTAssertTrue(app.buttons["photos.choose"].waitForExistence(timeout: 5))
        ProfileEditorNavigation.closeSection(in: app)

        ProfileEditorNavigation.open(.interests, in: app)
        let sports = app.buttons["interests.category.sports_fitness"]
        XCTAssertTrue(sports.waitForExistence(timeout: 5))
        sports.tap()
        let golf = app.buttons["interest.golf"]
        XCTAssertTrue(golf.waitForExistence(timeout: 5))
        golf.tap()
        ProfileEditorNavigation.closeSection(in: app)
        ProfileEditorNavigation.open(.interests, in: app)
        XCTAssertTrue(sports.waitForExistence(timeout: 5))
        sports.tap()
        XCTAssertTrue(golf.waitForExistence(timeout: 5))
        XCTAssertEqual(golf.value as? String, "Not selected")
        ProfileEditorNavigation.closeSection(in: app)

        ProfileEditorNavigation.open(.aboutMe, in: app)
        let name = app.textFields["profile.firstName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(" unsaved")
        ProfileEditorNavigation.closeSection(in: app)
        ProfileEditorNavigation.closeMenu(in: app)
        XCTAssertTrue(app.staticTexts["Fixture member"].exists)
        ProfileEditorNavigation.open(.aboutMe, in: app)
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Fixture member")
        ProfileEditorNavigation.closeSection(in: app)
        ProfileEditorNavigation.closeMenu(in: app)
    }

    @MainActor func testSavingProfileReturnsToItsUpdatedCard() {
        let app = launch()
        ProfileEditorNavigation.open(.aboutMe, in: app)
        let name = app.textFields["profile.firstName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Fixture member".count) + "Taylor")
        let save = app.buttons["profile.save"]
        for _ in 0..<4 {
            if save.isHittable { break }
            app.swipeUp()
        }
        save.tap()
        XCTAssertTrue(app.buttons["profile.editor.aboutMe"].waitForExistence(timeout: 5))
        ProfileEditorNavigation.closeMenu(in: app)
        XCTAssertTrue(app.staticTexts["Taylor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Profile"].isSelected)
        ProfileEditorNavigation.open(.aboutMe, in: app)
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Taylor")
    }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-messaging", "--ui-test-photos"]
        app.launch()
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 10))
        return app
    }
}
