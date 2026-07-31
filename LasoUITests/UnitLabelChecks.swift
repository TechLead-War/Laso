import XCTest

/// Temporary runtime check for the "number shown without a unit" fix pass.
final class UnitLabelChecks: XCTestCase {

    private func launch(route: String? = nil, tab: String = "home") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--ui-test-mode", "--ui-test-premium-showcase", "--ui-test-subscribed",
            "--ui-test-initial-tab=\(tab)"
        ]
        if let route { app.launchArguments.append("--ui-test-initial-route=\(route)") }
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "Allow While Using App", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 5) { button.tap() }
        }
        return app
    }

    private func shoot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/laso-units-\(name).png"))
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWeeklyReviewNamesTheStepUnit() throws {
        let app = launch(route: "weeklyReview")
        let stepsPerDay = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'steps/day'")
        ).firstMatch
        XCTAssertTrue(stepsPerDay.waitForExistence(timeout: 40), "No 'steps/day' label on the Weekly Review screen")
        shoot("weekly-review")
    }

    @MainActor
    func testAskYourDataAnswerCarriesAUnit() throws {
        let app = launch(route: "askYourData")
        let suggestion = app.staticTexts["How is my sleep this week?"].firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 40), "Ask suggestions never appeared")
        suggestion.tap()
        let answer = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS ' hrs'")
        ).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 40), "Sleep answer has no 'hrs' unit")
        shoot("ask-answer")
    }

    @MainActor
    func testTabScreenshots() throws {
        let app = launch()
        shoot("home")
        for tab in ["Live", "Biology"] {
            let button = app.buttons[tab].firstMatch
            if button.waitForExistence(timeout: 20) {
                button.tap()
                Thread.sleep(forTimeInterval: 6)
                shoot(tab.lowercased())
            }
        }
    }
}
