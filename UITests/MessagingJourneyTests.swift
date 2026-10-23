import XCTest

final class MessagingJourneyTests: XCTestCase {
    @MainActor
    func testConnectionOpensChatAndLostSendResponseRetriesOnce() {
        let app = launchFixture()
        app.tabBars.buttons["Discovery"].tap()
        app.segmentedControls.buttons["Connections"].tap()
        let message = app.buttons["Message Alex"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        message.tap()
        let composer = app.descendants(matching: .any).matching(identifier: "chat.composer").firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        composer.typeText("Coffee on Saturday?")
        app.buttons["chat.send"].tap()
        let retry = app.buttons["chat.retrySend"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        retry.tap()
        let confirmed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: retry)
        XCTAssertEqual(XCTWaiter.wait(for: [confirmed], timeout: 10), .completed)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "Coffee on Saturday?")).count, 1)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Conversation after safe send retry"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSwitchingAccountsClearsOldInboxAndChat() {
        let app = launchFixture()
        app.tabBars.buttons["Messages"].tap()
        let previous = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Account A conversation")
        ).firstMatch
        XCTAssertTrue(previous.waitForExistence(timeout: 10))
        app.tabBars.buttons["Profile"].tap()
        app.buttons["profile.settings"].tap()
        app.buttons["Sign out"].tap()
        XCTAssertTrue(app.buttons["Join or sign in"].waitForExistence(timeout: 10))
        app.buttons["Join or sign in"].tap()
        let email = app.textFields["signup.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.typeText("second@example.test")
        app.buttons["Send sign-in code"].tap()
        let code = app.textFields["signup.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        code.tap()
        code.typeText("123456")
        app.buttons["Verify email"].tap()
        XCTAssertTrue(app.tabBars.buttons["Messages"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Messages"].tap()
        let next = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Account B conversation"))
            .firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        XCTAssertFalse(previous.exists)
        next.tap()
        XCTAssertTrue(app.staticTexts["chat.peer"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["chat.peer"].label, "Taylor")
        XCTAssertFalse(previous.exists)
    }

    @MainActor
    func testSettingsOpensFromProfileAndReturnsToProfile() {
        let app = launchFixture()
        XCTAssertFalse(app.tabBars.buttons["Settings"].exists)
        app.tabBars.buttons["Profile"].tap()
        app.buttons["profile.settings"].tap()
        XCTAssertTrue(app.buttons["account.delete"].waitForExistence(timeout: 10))
        app.buttons["account.delete"].tap()
        XCTAssertTrue(app.alerts["Delete your account?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["profile.settings"].waitForExistence(timeout: 5))
    }

    @MainActor private func launchFixture() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-messaging"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Messages"].waitForExistence(timeout: 10))
        return app
    }
}
