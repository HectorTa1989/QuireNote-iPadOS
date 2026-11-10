import XCTest

final class QuireUITests: XCTestCase {
    func testOnboardingExplainsFileOwnership() {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Your notebooks are files"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Choose a Folder"].exists)
    }

    func testPrivacyPolicyIsAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Privacy"].waitForExistence(timeout: 5))
    }
}
