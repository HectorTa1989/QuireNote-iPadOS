import XCTest

@MainActor
final class QuireUITests: XCTestCase {
    func testOnboardingExplainsFileOwnership() {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Your notebooks are files"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Choose a Folder"].exists)
    }

    func testReviewDemoFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-QuireReviewDemo"]
        app.launch()

        XCTAssertTrue(app.buttons["New Notebook"].waitForExistence(timeout: 20), app.debugDescription)
        capture("01-library", in: app)

        app.buttons["New Notebook"].tap()
        capture("02-after-new-notebook-tap", in: app)
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5), app.debugDescription)
        let title = "Review Notebook \(UUID().uuidString.prefix(4))"
        let titleField = app.textFields["Title"]
        titleField.tap()
        titleField.press(forDuration: 1.1)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
        } else {
            titleField.doubleTap()
        }
        titleField.typeText(title)
        capture("02-new-notebook", in: app)
        app.buttons["Create"].tap()

        let notebook = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(notebook.waitForExistence(timeout: 20), app.debugDescription)
        capture("03-library-with-notebook", in: app)
        notebook.tap()
        XCTAssertTrue(app.buttons["Add Page"].waitForExistence(timeout: 20), app.debugDescription)
        capture("04-editor", in: app)
        app.buttons["Add Page"].tap()
        XCTAssertTrue(app.buttons["Page 2"].waitForExistence(timeout: 10), app.debugDescription)
        capture("05-second-page", in: app)
        app.buttons["Search Handwriting"].tap()
        XCTAssertTrue(app.staticTexts["Search your handwriting"].waitForExistence(timeout: 5), app.debugDescription)
        capture("06-handwriting-search", in: app)
        app.buttons["Done"].tap()

        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap() }
        let settings = app.buttons["Settings"]
        if settings.waitForExistence(timeout: 5) {
            settings.tap()
            let unlock = app.buttons["Unlock QuireNote Pro"]
            if unlock.waitForExistence(timeout: 5) {
                unlock.tap()
                XCTAssertTrue(app.staticTexts["Pay once. Keep your files."].waitForExistence(timeout: 5), app.debugDescription)
                capture("07-pro", in: app)
            }
        }
    }

    func testProPaywallScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-QuireReviewDemo"]
        app.launch()

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20), app.debugDescription)
        settings.tap()
        let unlock = app.buttons["Unlock QuireNote Pro"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 10), app.debugDescription)
        unlock.tap()
        XCTAssertTrue(app.staticTexts["Pay once. Keep your files."].waitForExistence(timeout: 10), app.debugDescription)
        capture("07-pro", in: app)
    }

    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
