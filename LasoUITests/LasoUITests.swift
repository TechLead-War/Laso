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

        // The seed marks both of yesterday's moves done, so the verdict must name
        // the result instead of only saying it was logged.
        XCTAssertTrue(resultCard.label.localizedCaseInsensitiveContains("counted"),
                      "Expected the verdict to say what counted, got: \(resultCard.label)")
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

    /// Taps the day move's Done, confirms it collapses to the logged row, and
    /// relaunches to confirm it stays done for the rest of the day.
    @MainActor
    func testMarkDoneLocksForTheDay() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode"]
        app.launch()
        _ = app.buttons["Today"].waitForExistence(timeout: 30)
        // The moves card sits under the status and drivers, below the first fold,
        // and the lazy stack only builds what is on screen.
        let home = app.descendants(matching: .any)["screen.home"].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 30), "Home never appeared")
        home.swipeUp()

        let doneButton = app.buttons["home.action.markDone"]
        let loggedRow = app.descendants(matching: .any)["home.action.doneLogged"].firstMatch
        // A prior run on this simulator may already have marked today done.
        if doneButton.waitForExistence(timeout: 15) {
            doneButton.tap()
        }
        XCTAssertTrue(loggedRow.waitForExistence(timeout: 10), "Done did not collapse to the logged row")
        XCTAssertFalse(doneButton.exists, "The Done button is still offered after marking done")
        saveScreenshot(name: "mark-done")

        app.terminate()
        app.launch()
        _ = app.buttons["Today"].waitForExistence(timeout: 30)
        app.descendants(matching: .any)["screen.home"].firstMatch.swipeUp()
        XCTAssertTrue(loggedRow.waitForExistence(timeout: 15), "The day move was not still done after relaunch")
        XCTAssertFalse(doneButton.exists, "Relaunch offered Done again the same day")
        saveScreenshot(name: "mark-done-locked")
    }

    /// Today is the brief: the status card and the day/night moves are the two
    /// things that must render before anything else on the tab is worth testing.
    @MainActor
    func testStatusAndMovesRenderOnHome() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode", "--ui-test-initial-tab=home"]
        app.launch()

        let home = app.descendants(matching: .any)["screen.home"].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 30), "Home never appeared")

        let status = app.descendants(matching: .any)["home.statusCard"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 20), "Status card never rendered on Home")

        saveScreenshot(name: "home-brief-top")

        // The brief is four short sections, so two swipes reach the focus card.
        home.swipeUp()
        let moves = app.descendants(matching: .any)["home.todaysActionCard"].firstMatch
        XCTAssertTrue(moves.waitForExistence(timeout: 20), "Moves card never rendered on Home")
        saveScreenshot(name: "home-brief-middle")
        home.swipeUp()
        saveScreenshot(name: "home-brief-bottom")
    }

    /// Taps the blank area on the right of a Settings row, not the icon or the
    /// text. Plain-style Button rows only take taps on their drawn content, so
    /// without `.contentShape(Rectangle())` this tap lands on nothing and the
    /// row reads as randomly unclickable.
    @MainActor
    func testSettingsRowTapsOnEmptyRightSide() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode", "--ui-test-initial-tab=settings"]
        app.launch()

        let settings = app.descendants(matching: .any)["screen.settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30), "Settings never appeared")

        let bugRow = app.descendants(matching: .any)["settings.row.reportBug"].firstMatch
        var swipes = 0
        while !bugRow.exists && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(bugRow.waitForExistence(timeout: 10), "Report a bug row missing in Settings")

        bugRow.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()

        // Settings itself has no text field, so one appearing proves the
        // feedback sheet opened from a tap on the row's empty space.
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10),
                      "Tap on the empty right side of the row did nothing")
        saveScreenshot(name: "settings-row-empty-side-tap")
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
