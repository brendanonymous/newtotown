import XCTest

final class ProfileEditorTests: XCTestCase {
    @MainActor func testAllProfileEditorsCloseBackToTheProfileTab() {
        let app = launch()
        app.buttons["My photos"].tap()
        XCTAssertTrue(app.buttons["photos.choose"].waitForExistence(timeout: 5))
        closeEditor(in: app)

        let interests = app.buttons["profile.interests"]
        XCTAssertEqual(interests.label, "Edit interests")
        interests.tap()
        let sports = app.buttons["interests.category.sports_fitness"]
        XCTAssertTrue(sports.waitForExistence(timeout: 5))
        sports.tap()
        let golf = app.buttons["interest.golf"]
        XCTAssertTrue(golf.waitForExistence(timeout: 5))
        golf.tap()
        closeEditor(in: app)
        interests.tap()
        XCTAssertTrue(sports.waitForExistence(timeout: 5))
        sports.tap()
        XCTAssertTrue(golf.waitForExistence(timeout: 5))
        XCTAssertEqual(golf.value as? String, "Not selected")
        closeEditor(in: app)

        app.buttons["profile.edit"].tap()
        let name = app.textFields["profile.firstName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(" unsaved")
        closeEditor(in: app)
        XCTAssertTrue(app.staticTexts["Fixture member"].exists)
        app.buttons["profile.edit"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Fixture member")
        closeEditor(in: app)
    }

    @MainActor func testSavingProfileReturnsToItsUpdatedCard() {
        let app = launch()
        app.buttons["profile.edit"].tap()
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
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Taylor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Profile"].isSelected)
        app.buttons["profile.edit"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Taylor")
    }

    @MainActor private func closeEditor(in app: XCUIApplication) {
        app.buttons["editor.close"].tap()
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Profile"].isSelected)
    }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-messaging", "--ui-test-photos"]
        app.launch()
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 10))
        return app
    }
}
