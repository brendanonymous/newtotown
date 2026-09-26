import XCTest

final class SignupEntryTests: XCTestCase {
    @MainActor
    func testInvalidEmailDoesNotAdvanceToVerification() {
        let app = XCUIApplication()
        app.launch()
        let join = app.buttons["Join or sign in"]
        XCTAssertTrue(join.waitForExistence(timeout: 10))
        join.tap()
        let email = app.textFields["signup.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.typeText("invalid-email")
        app.buttons["Send sign-in code"].tap()
        let error = app.staticTexts["signup.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(error.label, "Enter a valid email address.")
        XCTAssertFalse(app.textFields["signup.code"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Signup validation"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // The app owns the model now; reopening must still start a fresh email form.
        app.buttons["Close"].tap()
        join.tap()
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        XCTAssertNotEqual(email.value as? String, "invalid-email")
        XCTAssertFalse(app.staticTexts["signup.error"].exists)
    }
}
