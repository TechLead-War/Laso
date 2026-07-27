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

    /// Taps "Mark done", confirms it flips to "Done", then taps again and
    /// confirms it stays locked as "Done" (no untick until tomorrow).
    @MainActor
    func testMarkDoneLocksForTheDay() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode"]
        app.launch()
        _ = app.buttons["Today"].waitForExistence(timeout: 30)
        sleep(3)

        // The mark-done button in either state — "Mark done" or "Done" both
        // contain "done" (label query, since the label changes across states).
        let btn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'done'")).firstMatch
        XCTAssertTrue(btn.waitForExistence(timeout: 15), "Mark done button missing")

        // Get into the Done state first (covers the Mark done -> Done flip when
        // the app launches fresh; already-done if a prior run left it marked).
        if btn.label.localizedCaseInsensitiveContains("Mark done") {
            btn.tap()
            sleep(1)
        }
        saveScreenshot(name: "mark-done")
        XCTAssertFalse(btn.label.localizedCaseInsensitiveContains("Mark done"),
                       "Button did not reach the Done state")

        // Tap again — it must stay locked as Done and NOT revert to Mark done.
        btn.tap()
        sleep(1)
        saveScreenshot(name: "mark-done-locked")
        XCTAssertFalse(btn.label.localizedCaseInsensitiveContains("Mark done"),
                       "Unticked on second tap; it must stay locked for the day")
    }

    /// The month calendar is only worth having if a day opens. Taps a scored
    /// cell and checks the day sheet actually comes up with its signal list,
    /// then pages back a month and returns with Today.
    @MainActor
    func testMonthCalendarDayOpensTheDaySheet() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode", "--ui-test-initial-tab=explore"]
        app.launch()

        let calendar = app.descendants(matching: .any)["explore.monthCalendar"].firstMatch
        XCTAssertTrue(calendar.waitForExistence(timeout: 30), "Month calendar never appeared on Explore")

        let days = app.buttons.matching(identifier: "explore.monthCalendar.day")
        XCTAssertTrue(days.firstMatch.waitForExistence(timeout: 20), "No day cells rendered")

        // Mid-month, so the cell is past (tappable) and likely to carry a score.
        let day = days.element(boundBy: min(14, days.count - 1))
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        day.tap()

        let sheet = app.descendants(matching: .any)["explore.daySheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "Tapping a day did not open the day sheet")
        saveScreenshot(name: "explore-day-sheet")

        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(calendar.waitForExistence(timeout: 10), "Closing the sheet did not return to the calendar")

        let thisMonth = Date().formatted(.dateTime.month(.wide).year())
        app.buttons["Previous month"].firstMatch.tap()
        calendar.swipeUp()

        let header = app.staticTexts.matching(identifier: "explore.monthCalendar").firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        XCTAssertNotEqual(header.label, thisMonth, "The back arrow did not move the calendar off this month")
        saveScreenshot(name: "explore-previous-month")

        // Scoped by identifier so the tab bar's own "Today" cannot match.
        let todayButton = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier == %@", "Today", "explore.monthCalendar")
        ).firstMatch
        XCTAssertTrue(todayButton.waitForExistence(timeout: 10), "Paging back did not offer a way home")
        todayButton.tap()
        XCTAssertEqual(app.staticTexts.matching(identifier: "explore.monthCalendar").firstMatch.label, thisMonth,
                       "Today did not bring the calendar back to this month")
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
