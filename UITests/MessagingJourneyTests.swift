import XCTest

final class MessagingJourneyTests: XCTestCase {
    @MainActor
    func testMessageInputStopsAtLimitAndAllowsDeletion() {
        let app = launchFixture(emptyChat: true)
        app.tabBars.buttons["Connections"].tap()
        let message = app.buttons["Message Alex"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        message.tap()
        let composer = app.textFields["chat.composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        composer.typeText(String(repeating: "a", count: 501))
        XCTAssertEqual(composer.value as? String, String(repeating: "a", count: 500))
        let counter = app.staticTexts["chat.characterCount"]
        XCTAssertEqual(counter.label, "Character limit reached · 500/500")
        XCTAssertTrue(app.buttons["chat.send"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Message character limit and rounded input"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        composer.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual(counter.label, "499/500")
        composer.typeText("b")
        XCTAssertEqual(composer.value as? String, String(repeating: "a", count: 499) + "b")
        XCTAssertEqual(counter.label, "Character limit reached · 500/500")
    }

    @MainActor
    func testConnectionOpensChatAndLostSendResponseRetriesOnce() {
        let app = launchFixture(emptyChat: true)
        app.tabBars.buttons["Connections"].tap()
        XCTAssertFalse(app.segmentedControls["Browse"].exists)
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
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["No connections yet."].waitForExistence(timeout: 10))
        app.tabBars.buttons["Messages"].tap()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Coffee on Saturday?")).firstMatch
                .waitForExistence(timeout: 10))
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
        app.buttons["signup.switchMethod"].tap()
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
    func testPhoneCodeSignsIntoTheNextAccount() {
        let app = launchFixture()
        app.tabBars.buttons["Profile"].tap()
        app.buttons["profile.settings"].tap()
        app.buttons["Sign out"].tap()
        XCTAssertTrue(app.buttons["Join or sign in"].waitForExistence(timeout: 10))
        app.buttons["Join or sign in"].tap()
        let phone = app.textFields["signup.phone"]
        XCTAssertTrue(phone.waitForExistence(timeout: 10))
        phone.tap()
        phone.typeText("4805550142")
        app.buttons["Send sign-in code"].tap()
        let code = app.textFields["signup.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        code.tap()
        code.typeText("123456")
        app.buttons["Verify phone"].tap()
        XCTAssertTrue(app.tabBars.buttons["Messages"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Messages"].tap()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Account B conversation"))
                .firstMatch.waitForExistence(timeout: 10))
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

    @MainActor
    func testOpeningAnEmptyChatKeepsTheConnection() {
        let app = launchFixture(emptyChat: true)
        app.tabBars.buttons["Connections"].tap()
        let message = app.buttons["Message Alex"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        message.tap()
        XCTAssertTrue(app.staticTexts["Say hello."].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        app.tabBars.buttons["Messages"].tap()
        XCTAssertTrue(app.staticTexts["Start with hello."].waitForExistence(timeout: 10))
    }

    @MainActor
    func testReportingAConnectionRemovesItFromEveryList() {
        let app = launchFixture(emptyChat: true)
        app.tabBars.buttons["Connections"].tap()
        let report = app.buttons["Report Alex"]
        XCTAssertTrue(report.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Block Alex"].exists)
        report.tap()
        XCTAssertFalse(app.buttons["report.submit"].isEnabled)
        app.buttons["report.reason"].tap()
        app.buttons["Spam"].tap()
        app.buttons["report.submit"].tap()
        XCTAssertTrue(app.staticTexts["Report submitted"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["No connections yet."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Message Alex"].exists)
        app.tabBars.buttons["Messages"].tap()
        XCTAssertTrue(app.staticTexts["Start with hello."].waitForExistence(timeout: 10))
        app.tabBars.buttons["Discovery"].tap()
        XCTAssertFalse(app.buttons["Connect with Alex"].exists)
    }

    @MainActor
    func testReportFromMessagesCancelsWithoutLosingDraftThenRetriesAndRemovesChat() {
        let app = launchFixture(lostReportResponse: true)
        app.tabBars.buttons["Messages"].tap()
        let thread = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Account A conversation"))
            .firstMatch
        XCTAssertTrue(thread.waitForExistence(timeout: 10))
        thread.tap()
        let composer = app.descendants(matching: .any).matching(identifier: "chat.composer").firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        composer.typeText("Unsaved draft")
        app.buttons["Report"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10))
        app.buttons["Close"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertEqual(composer.value as? String, "Unsaved draft")
        app.buttons["Report"].tap()
        app.buttons["report.reason"].tap()
        app.buttons["Spam"].tap()
        app.buttons["report.submit"].tap()
        XCTAssertTrue(
            app.staticTexts["We couldn’t confirm your report. Try again to check its submission."]
                .waitForExistence(timeout: 10))
        app.buttons["report.submit"].tap()
        XCTAssertTrue(app.staticTexts["Report submitted"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Start with hello."].waitForExistence(timeout: 10))
        XCTAssertFalse(composer.exists)
        XCTAssertFalse(thread.exists)
        app.tabBars.buttons["Connections"].tap()
        XCTAssertTrue(app.staticTexts["No connections yet."].waitForExistence(timeout: 10))
    }

    @MainActor
    func testAgePreferencesSaveAndReopen() {
        let app = launchFixture()
        app.tabBars.buttons["Profile"].tap()
        let preferences = app.buttons["profile.preferences"]
        XCTAssertTrue(preferences.waitForExistence(timeout: 10))
        preferences.tap()
        let maximum = app.textFields["preferences.maximumAge"]
        XCTAssertTrue(maximum.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["preferences.save"].isEnabled)
        maximum.tap()
        maximum.typeText("40")
        app.swipeUp()
        app.buttons["preferences.save"].tap()
        XCTAssertTrue(preferences.waitForExistence(timeout: 10))
        preferences.tap()
        XCTAssertTrue(maximum.waitForExistence(timeout: 10))
        XCTAssertEqual(maximum.value as? String, "40")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved discovery age preferences"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testMessageProfileOpensAndReturnsWithDraft() {
        let app = launchFixture()
        app.tabBars.buttons["Messages"].tap()
        let thread = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Account A conversation")
        ).firstMatch
        XCTAssertTrue(thread.waitForExistence(timeout: 10))
        thread.tap()
        let composer = app.descendants(matching: .any).matching(identifier: "chat.composer").firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        composer.typeText("Unsaved plan")
        app.buttons["chat.viewProfile"].tap()
        XCTAssertTrue(app.staticTexts["About me: Find a hiking buddy."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Scottsdale"].exists)
        XCTAssertFalse(composer.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertEqual(composer.value as? String, "Unsaved plan")
    }

    @MainActor
    func testVisibilityTogglePersistsWhenSettingsReopens() {
        let app = launchFixture()
        app.tabBars.buttons["Profile"].tap()
        app.buttons["profile.settings"].tap()
        let toggle = app.switches["settings.profileVisibility"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.tap()
        XCTAssertTrue(app.staticTexts["Your profile is hidden"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["profile.settings"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
    }

    @MainActor
    func testTabTitlesUseTheSameVerticalPosition() {
        let app = launchFixture()
        app.tabBars.buttons["Messages"].tap()
        let messages = app.staticTexts["messages.title"]
        XCTAssertTrue(messages.waitForExistence(timeout: 10))
        let preferredTop = messages.frame.minY
        let preferredLeft = messages.frame.minX
        let logoTop = app.images["NewToTown"].frame.minY

        app.tabBars.buttons["Connections"].tap()
        let connections = app.staticTexts["connections.title"]
        XCTAssertTrue(connections.waitForExistence(timeout: 10))
        XCTAssertEqual(connections.frame.minY, preferredTop, accuracy: 1)
        XCTAssertEqual(connections.frame.minX, preferredLeft, accuracy: 1)

        for tab in ["Discovery", "Profile", "Messages"] {
            app.tabBars.buttons[tab].tap()
            let logo = app.images["NewToTown"]
            XCTAssertTrue(logo.waitForExistence(timeout: 10))
            XCTAssertEqual(logo.frame.minY, logoTop, accuracy: 1, "Navigation height changed on \(tab)")
        }
        XCTAssertEqual(messages.frame.minY, preferredTop, accuracy: 1)
    }

    @MainActor private func launchFixture(emptyChat: Bool = false, lostReportResponse: Bool = false)
        -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-messaging"]
        if emptyChat { app.launchArguments.append("--ui-test-empty-chat") }
        if lostReportResponse { app.launchArguments.append("--ui-test-report-lost-response") }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Messages"].waitForExistence(timeout: 10))
        return app
    }
}
