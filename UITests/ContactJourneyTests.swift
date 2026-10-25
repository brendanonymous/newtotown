import XCTest

final class ContactJourneyTests: XCTestCase {
    @MainActor func testPhoneAccountCanAddVerifiedEmail() {
        verifyMissingContact(kind: "email", value: "alex@example.com", preserved: "+14805550123")
    }
    @MainActor func testEmailAccountCanAddVerifiedPhone() {
        verifyMissingContact(kind: "phone", value: "4805550124", preserved: "member@example.com")
    }
    @MainActor private func verifyMissingContact(kind: String, value: String, preserved: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-messaging", "--ui-test-contacts"]
        if kind == "phone" { app.launchArguments.append("--ui-test-email-account") }
        app.launch()
        let settings = app.buttons["profile.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()
        app.buttons["settings.personalInfo"].tap()
        let add = app.buttons["account.add.\(kind)"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let input = app.textFields["contact.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText(value)
        app.buttons["contact.send"].tap()
        let code = app.textFields["contact.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Verify \(kind)"
        screenshot.lifetime = .keepAlways
        self.add(screenshot)
        code.tap()
        code.typeText("000000")
        app.buttons["contact.verify"].tap()
        XCTAssertTrue(app.staticTexts["contact.error"].waitForExistence(timeout: 5))
        code.tap()
        code.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "123456")
        app.buttons["contact.verify"].tap()
        let detail = app.staticTexts["account.\(kind)"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertEqual(detail.label, kind == "phone" ? "+14805550124" : value)
        XCTAssertFalse(app.buttons["account.add.\(kind)"].exists)
        XCTAssertTrue(app.staticTexts[preserved].exists)
    }
}
