import XCTest

final class HealthPulseVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Onboarding Flow

    func testOnboardingDark() throws {
        try runOnboardingFlow(appearance: "Dark")
    }

    func testOnboardingLight() throws {
        try runOnboardingFlow(appearance: "Light")
    }

    // MARK: - Main Tabs

    func testMainFlowDark() throws {
        try runMainFlow(appearance: "Dark")
    }

    func testMainFlowLight() throws {
        try runMainFlow(appearance: "Light")
    }

    // MARK: - Home Detail Screens

    func testHomeDetailsDark() throws {
        try runHomeDetails(appearance: "Dark")
    }

    func testHomeDetailsLight() throws {
        try runHomeDetails(appearance: "Light")
    }

    // MARK: - Settings

    func testSettingsDark() throws {
        try runSettings(appearance: "Dark")
    }

    func testSettingsLight() throws {
        try runSettings(appearance: "Light")
    }

    // MARK: - Flow: Onboarding

    private func runOnboardingFlow(appearance: String) throws {
        let theme = appearance.lowercased()
        let app = launchApp(showOnboarding: true, appearance: appearance)

        // 1. Welcome
        XCTAssertTrue(app.staticTexts["HealthPulse"].waitForExistence(timeout: 12))
        ScreenshotStore.capture(app: app, theme: theme, profile: "onboarding", step: "welcome")

        // 2. Value Proposition
        let getStarted = app.buttons["Get Started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()
        XCTAssertTrue(app.staticTexts["What You Get"].waitForExistence(timeout: 5))
        ScreenshotStore.capture(app: app, theme: theme, profile: "onboarding", step: "value-proposition")

        // 3. Profile Capture
        tapFirstButton(app, label: "Continue")
        if app.staticTexts["About You"].waitForExistence(timeout: 5) {
            ScreenshotStore.capture(app: app, theme: theme, profile: "onboarding", step: "profile-capture")
        }

        // 4. Fill profile form to advance: age (required) + gender (required, menu picker)
        // Type age into the age text field
        let ageField = app.textFields["e.g. 28"]
        if ageField.waitForExistence(timeout: 3) {
            ageField.tap()
            ageField.typeText("28")
            // Dismiss number pad by tapping on the heading area
            let heading = app.staticTexts["About You"]
            if heading.exists {
                heading.tap()
            }
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Select gender from the Picker (menu style) — tap the picker, then the option
        let genderPicker = app.buttons["Gender, Select"]
        if genderPicker.waitForExistence(timeout: 2) {
            genderPicker.tap()
            // Select "Male" from the popup menu to avoid cycle opt-in step
            let maleOption = app.buttons["Male"]
            if maleOption.waitForExistence(timeout: 3) {
                maleOption.tap()
            }
        }

        // Tap Continue to advance to Connect Health
        tapFirstButton(app, label: "Continue")
        if app.staticTexts["Connect Apple Health"].waitForExistence(timeout: 5) {
            ScreenshotStore.capture(app: app, theme: theme, profile: "onboarding", step: "connect-health")
        }

        // 5. Skip Connect Health to reach Focus Selection
        skipConnectHealth(app)

        // 6. Focus Selection
        if app.staticTexts["What matters most to you?"].waitForExistence(timeout: 5) {
            ScreenshotStore.capture(app: app, theme: theme, profile: "onboarding", step: "focus-selection")
        }
    }

    // MARK: - Flow: Main Tabs

    private func runMainFlow(appearance: String) throws {
        let theme = appearance.lowercased()
        let app = launchApp(showOnboarding: false, appearance: appearance)

        // Home
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 12))
        ScreenshotStore.capture(app: app, theme: theme, profile: "main", step: "home")

        // Live
        app.buttons["tab.live"].tap()
        _ = app.staticTexts["Live"].waitForExistence(timeout: 12)
        ScreenshotStore.capture(app: app, theme: theme, profile: "main", step: "live")

        // Explore
        app.buttons["tab.explore"].tap()
        _ = app.staticTexts["Explore"].waitForExistence(timeout: 12)
        ScreenshotStore.capture(app: app, theme: theme, profile: "main", step: "explore")
    }

    // MARK: - Flow: Home Detail Screens

    private func runHomeDetails(appearance: String) throws {
        let theme = appearance.lowercased()
        let app = launchApp(showOnboarding: false, appearance: appearance)
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 12))

        // Recovery Card → Score Guide (taps but opens sheet, not navigation)
        captureDetailIfAvailable(app: app, theme: theme, cardID: "home.recoveryCard", step: "recovery-hero", isSheet: true)

        // Vitality Detail
        captureDetailIfAvailable(app: app, theme: theme, cardID: "home.vitalityCard", step: "vitality-detail")

        // Sleep Coach
        captureDetailIfAvailable(app: app, theme: theme, cardID: "home.sleepCoachCard", step: "sleep-coach")

        // Strain Detail
        captureDetailIfAvailable(app: app, theme: theme, cardID: "home.strainCard", step: "strain-detail")

        // Stress Monitor
        captureDetailIfAvailable(app: app, theme: theme, cardID: "home.stressCard", step: "stress-monitor")

        // Cycle Detail (female users only)
        captureDetailIfAvailable(app: app, theme: theme, cardID: "home.cycleCard", step: "cycle-detail")

        // Insights Detail
        captureDetailIfAvailable(app: app, theme: theme, cardID: "home.insightsCard", step: "insights-detail")

        // Weekly Review
        captureDetailIfAvailable(app: app, theme: theme, cardID: "home.weeklyReviewCard", step: "weekly-review")

        // Achievements
        captureDetailIfAvailable(app: app, theme: theme, cardID: "home.levelBadgeCard", step: "achievements")
    }

    // MARK: - Flow: Settings

    private func runSettings(appearance: String) throws {
        let theme = appearance.lowercased()
        let app = launchApp(showOnboarding: false, appearance: appearance)
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 12))

        // Open Settings sheet
        let settingsButton = app.buttons["home.settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else { return }
        settingsButton.tap()

        // Wait for settings navigation bar
        if app.navigationBars["Settings"].waitForExistence(timeout: 5) {
            ScreenshotStore.capture(app: app, theme: theme, profile: "settings", step: "main")
        }

        // Connected Devices (navigate via Manage Devices row)
        let devicesRow = app.cells.containing(.staticText, identifier: "Manage Devices").firstMatch
        if devicesRow.waitForExistence(timeout: 3) {
            devicesRow.tap()
            Thread.sleep(forTimeInterval: 0.5)
            ScreenshotStore.capture(app: app, theme: theme, profile: "settings", step: "connected-devices")

            // Go back to Settings
            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Dismiss settings
        let doneButton = app.buttons["settings.doneButton"]
        if doneButton.exists {
            doneButton.tap()
        }
    }

    // MARK: - Helpers

    /// Taps a card by accessibility identifier, captures a screenshot of the resulting screen, then navigates back.
    /// Scrolls to find the card if it's not immediately visible. Silently skips if the card doesn't exist
    /// (e.g., data-dependent cards like Stress or Cycle).
    private func captureDetailIfAvailable(
        app: XCUIApplication,
        theme: String,
        cardID: String,
        step: String,
        isSheet: Bool = false
    ) {
        let card = app.buttons[cardID]

        // Try to find the card, scrolling if needed
        if !card.waitForExistence(timeout: 2) {
            // Scroll down to find it
            app.swipeUp()
            guard card.waitForExistence(timeout: 2) else { return }
        }

        // Ensure it's hittable (visible on screen)
        if !card.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
            guard card.isHittable else { return }
        }

        card.tap()
        Thread.sleep(forTimeInterval: 0.8)
        ScreenshotStore.capture(app: app, theme: theme, profile: "detail", step: step)

        // Navigate back
        if isSheet {
            // Dismiss sheet by tapping outside or finding close button
            let closeButtons = ["Close", "Done", "Dismiss"]
            var dismissed = false
            for label in closeButtons {
                let btn = app.buttons[label]
                if btn.exists {
                    btn.tap()
                    dismissed = true
                    break
                }
            }
            if !dismissed {
                // Swipe down to dismiss sheet
                app.swipeDown()
            }
        } else {
            // Pop navigation stack — tap the back button
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
            }
        }
        Thread.sleep(forTimeInterval: 0.5)

        // Scroll back to top for next card
        // Only scroll up if we previously scrolled down
        let homeScreen = app.otherElements["screen.home"]
        if homeScreen.exists {
            // Tap status bar area to scroll to top
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    private func tapFirstButton(_ app: XCUIApplication, label: String) {
        let buttons = app.buttons.matching(identifier: label)
        guard buttons.firstMatch.waitForExistence(timeout: 3) else { return }
        if !buttons.firstMatch.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        if buttons.firstMatch.isHittable {
            buttons.firstMatch.tap()
        }
    }

    private func skipConnectHealth(_ app: XCUIApplication) {
        // In UI test mode, the app skips actual HealthKit authorization,
        // so tapping "Connect Health Data" immediately advances.
        let labels = ["Connect Health Data", "Continue Anyway", "Skip for now"]
        for label in labels {
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 2) {
                if btn.isHittable {
                    btn.tap()
                } else {
                    btn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                return
            }
        }
    }

    private func launchApp(showOnboarding: Bool, appearance: String = "Dark") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-test-mode",
            "--ui-test-reset-defaults"
        ]
        if appearance == "Light" {
            app.launchArguments.append("--ui-test-appearance-light")
        }
        if showOnboarding {
            app.launchArguments.append("--ui-test-show-onboarding")
        }
        app.launch()
        return app
    }
}
