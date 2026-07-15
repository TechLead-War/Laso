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
