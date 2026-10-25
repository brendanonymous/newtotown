import XCTest

final class SignupEntryTests: XCTestCase {
    @MainActor
    func testSignupStartsWithPhoneAndRejectsInvalidNumber() {
        let app = XCUIApplication()
        app.launch()
        let join = app.buttons["Join or sign in"]
        XCTAssertTrue(join.waitForExistence(timeout: 10))
        join.tap()
        let phone = app.textFields["signup.phone"]
        XCTAssertTrue(phone.waitForExistence(timeout: 10))
        phone.tap()
        phone.typeText("480")
        app.buttons["Send sign-in code"].tap()
        XCTAssertTrue(app.staticTexts["signup.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["signup.code"].exists)
        XCTAssertFalse(app.textFields["signup.email"].exists)
    }

    @MainActor
    func testInvalidEmailDoesNotAdvanceToVerification() {
        let app = XCUIApplication()
        app.launch()
        let join = app.buttons["Join or sign in"]
        XCTAssertTrue(join.waitForExistence(timeout: 10))
        join.tap()
        app.buttons["signup.switchMethod"].tap()
        let email = app.textFields["signup.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.typeText("invalid-email")
        app.buttons["Send sign-in code"].tap()
        let error = app.staticTexts["signup.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(error.label, "Enter a valid email address.")
        XCTAssertFalse(app.textFields["signup.code"].exists)
        // Signup is rooted in the window, rather than a partially raised sheet.
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertTrue(app.images["NewToTown"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Signup validation"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // The app owns the model now; reopening must still start a fresh email form.
        app.buttons["Close"].tap()
        join.tap()
        app.buttons["signup.switchMethod"].tap()
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        XCTAssertNotEqual(email.value as? String, "invalid-email")
        XCTAssertFalse(app.staticTexts["signup.error"].exists)
    }
}
