import XCTest

/// Shared user navigation, keeping feature journeys focused on their behavior.
@MainActor enum ProfileEditorNavigation {
    enum Section: String { case photos, aboutMe, interests }

    static func open(_ section: Section, in app: XCUIApplication) {
        if !app.buttons["profile.editor.aboutMe"].exists {
            let edit = app.buttons["profile.edit"]
            XCTAssertTrue(edit.waitForExistence(timeout: 10))
            for _ in 0..<6 {
                if edit.isHittable { break }
                app.swipeUp()
            }
            edit.tap()
        }
        let row = app.buttons["profile.editor.\(section.rawValue)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
    }

    static func closeSection(in app: XCUIApplication) {
        app.buttons["editor.close"].tap()
        XCTAssertTrue(app.buttons["profile.editor.aboutMe"].waitForExistence(timeout: 5))
    }

    static func closeMenu(in app: XCUIApplication) {
        let close = app.buttons["profile.editor.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 5))
    }
}
