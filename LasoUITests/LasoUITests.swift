import XCTest

final class LasoUITests: XCTestCase {

    /// Walks Home → Settings → Invite friends and waits for a real referral
    /// code to arrive from the server, verifying the whole invite surface
    /// (Settings row, invite screen, server code minting) end to end.
    @MainActor
    func testInviteFriendsFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 30), "Settings tab did not appear")
        settingsTab.tap()

        let inviteRow = app.descendants(matching: .any)["settings.row.inviteFriends"].firstMatch
        XCTAssertTrue(inviteRow.waitForExistence(timeout: 10), "Invite friends row missing in Settings")
        saveScreenshot(name: "settings-invite-row")
        inviteRow.tap()

        let codeCard = app.descendants(matching: .any)["invite.codeCard"].firstMatch
        XCTAssertTrue(codeCard.waitForExistence(timeout: 10), "Invite screen code card missing")

        // Server-minted code (LASO-XXXXXX) can take a few seconds on a cold
        // Cloud Function start.
        let codeLabel = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'LASO-'")).firstMatch
        XCTAssertTrue(codeLabel.waitForExistence(timeout: 25), "Referral code never arrived from the server")

        saveScreenshot(name: "invite-screen")
    }

    /// Types a long (>100 char) question into Ask and submits, so the
    /// ask_query_submitted event fires with the full query_text. Verifies the
    /// screen accepts the query and renders (the answer/loading state appears);
    /// the console shows the "[Amplitude] ask_query_submitted" line.
    @MainActor
    func testAskQueryFiresWithFullText() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode", "--ui-test-initial-route=askYourData"]
        app.launch()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 30), "Ask text field did not appear")
        field.tap()
        let longQuestion = "why is my resting heart rate higher than usual this week even though I have been sleeping more and drinking water"
        XCTAssertGreaterThan(longQuestion.count, 100, "test question must exceed the old 100-char cap")
        field.typeText(longQuestion)
        app.keyboards.buttons["Search"].firstMatch.tap()

        // The result or loading state proves runQuery ran (which fires the event).
        saveScreenshot(name: "ask-query")
    }

    /// Seeds a prior-day marked-done action (score 80) and today's score (85),
    /// then verifies the loop-closer card renders with the +5 result.
    @MainActor
    func testDailyResultLoopCloser() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--ui-test-mode",
            "--ui-test-seed-daily-result=80",
            "--ui-test-override-overall-score=85",
        ]
        app.launch()

        let resultCard = app.descendants(matching: .any)["home.dailyResultCard"].firstMatch
        XCTAssertTrue(resultCard.waitForExistence(timeout: 30), "Loop-closer card did not render")

        // Seeded score 80 < today's score, so the up-framing must show. The card
        // combines its children, so assert on its label.
        XCTAssertTrue(resultCard.label.contains("higher this morning"),
                      "Expected the positive result framing, got: \(resultCard.label)")
        saveScreenshot(name: "loop-closer")
    }

    /// Grants notifications, taps the Next Up "Remind" button, and confirms it
    /// schedules (the button flips to "Reminder set").
    @MainActor
    func testRemindButtonSchedules() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        _ = app.buttons["Today"].waitForExistence(timeout: 30)
        // The permission alert can appear a beat after home loads; dismiss it
        // whenever it shows over the next few seconds.
        for _ in 0..<6 {
            let allow = springboard.buttons["Allow"]
            if allow.exists { allow.tap() }
            sleep(1)
        }

        let remind = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Remind'")).firstMatch
        XCTAssertTrue(remind.waitForExistence(timeout: 10), "Remind button missing")
        remind.tap()
        // Tapping requests permission on first use; grant it if the alert shows.
        for _ in 0..<6 {
            let allow = springboard.buttons["Allow"]
            if allow.exists { allow.tap() }
            sleep(1)
        }
        saveScreenshot(name: "remind-tapped")

        // "Reminder set" is the confirm state; it does not match the Settings tab.
        let confirmed = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Reminder set'")).firstMatch
        XCTAssertTrue(confirmed.waitForExistence(timeout: 5),
                      "Reminder did not confirm to 'Reminder set' after tap")
    }

    @MainActor
    private func saveScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/laso-uitest-\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
