import XCTest

final class HealthPulseVisualUITests: XCTestCase {
    private enum Theme: String {
        case light
        case dark
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainFlowLight() throws {
        try runMainFlow(theme: .light)
    }

    func testMainFlowDark() throws {
        try runMainFlow(theme: .dark)
    }

    func testOnboardingEntryLight() throws {
        let app = launchApp(theme: .light, showOnboarding: true)
        XCTAssertTrue(app.staticTexts["You vs You"].waitForExistence(timeout: 12))
        ScreenshotStore.capture(app: app, theme: Theme.light.rawValue, profile: "onboarding", step: "entry")
    }

    private func runMainFlow(theme: Theme) throws {
        let app = launchApp(theme: theme, showOnboarding: false)

        // Home
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 12))
        ScreenshotStore.capture(app: app, theme: theme.rawValue, profile: "main", step: "home")

        // Live
        app.buttons["tab.live"].tap()
        XCTAssertTrue(app.staticTexts["Live"].waitForExistence(timeout: 12))
        ScreenshotStore.capture(app: app, theme: theme.rawValue, profile: "main", step: "live")

        // Explore
        app.buttons["tab.explore"].tap()
        XCTAssertTrue(app.staticTexts["Explore"].waitForExistence(timeout: 12))
        ScreenshotStore.capture(app: app, theme: theme.rawValue, profile: "main", step: "explore")
    }

    private func launchApp(theme: Theme, showOnboarding: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-test-mode",
            "--ui-test-reset-defaults"
        ]
        if showOnboarding {
            app.launchArguments.append("--ui-test-show-onboarding")
        }
        app.launchEnvironment["HP_UI_THEME"] = theme.rawValue
        app.launch()
        return app
    }
}
