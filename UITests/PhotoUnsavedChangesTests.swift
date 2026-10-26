import XCTest

final class PhotoUnsavedChangesTests: XCTestCase {
    @MainActor func testUnchangedPhotoSheetClosesWithoutPrompt() {
        let app = launch()
        app.buttons["editor.close"].tap()
        XCTAssertTrue(app.buttons["My photos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    @MainActor func testCloseCanKeepEditingOrDiscardPhotoChanges() {
        let app = launch()
        app.buttons["photos.removeOne"].tap()
        app.buttons["editor.close"].tap()
        let alert = app.alerts["Leave without saving?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Keep editing"].tap()
        XCTAssertEqual(app.buttons["photos.editorGallery"].value as? String, "1 of 2")
        XCTAssertTrue(app.buttons["photos.save"].exists)
        app.buttons["editor.close"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Discard changes"].tap()
        XCTAssertTrue(app.buttons["My photos"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["photos.gallery"].value as? String, "1 of 3")
        app.buttons["My photos"].tap()
        XCTAssertTrue(app.buttons["photos.editorGallery"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["photos.editorGallery"].value as? String, "1 of 3")
        app.buttons["editor.close"].tap()
        XCTAssertTrue(app.buttons["My photos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    @MainActor func testSwipeDownPromptsBeforeDiscardingChanges() {
        let app = launch()
        app.buttons["photos.removeOne"].tap()
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.05, thenDragTo: end)
        let alert = app.alerts["Leave without saving?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Keep editing"].tap()
        XCTAssertEqual(app.buttons["photos.editorGallery"].value as? String, "1 of 2")
        XCTAssertTrue(app.buttons["photos.save"].exists)
    }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-test-messaging", "--ui-test-photos", "--ui-test-saved-photo", "--ui-test-photo-gallery",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["My photos"].waitForExistence(timeout: 10))
        app.buttons["My photos"].tap()
        XCTAssertTrue(app.buttons["photos.editorGallery"].waitForExistence(timeout: 5))
        return app
    }
}
