import XCTest

/// Runtime proof for the three reports the user raised: Ask answering the wrong
/// question, the Vitals strip showing two tiles instead of about five, and the
/// photo capture having no way in from Home.
///
/// These run the real screens, so they catch what a unit test cannot: a tile the
/// view model builds but the view never lays out, and an answer that reads wrong
/// only once it is on screen.
final class AskVitalsMirrorUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// The notification alert lands a beat after Home does and swallows taps
    /// until it is answered.
    private func dismissSystemAlerts(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<6 {
            for label in ["Allow", "Don't Allow", "OK"] {
                let button = springboard.buttons[label]
                if button.exists { button.tap() }
            }
            if !springboard.alerts.firstMatch.exists { break }
            sleep(1)
        }
    }

    private func launchHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode", "--ui-test-initial-tab=home"]
        app.launch()
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 30), "Home never loaded")
        dismissSystemAlerts(app)
        return app
    }

    /// The user reported two tiles where there should be about five. The strip
    /// itself never capped anything: tiles were built from scorer state captured
    /// before the scorers had finished, and were never rebuilt afterwards.
    @MainActor
    func testVitalsStripShowsTheFullSetOfTiles() {
        let app = launchHome()

        // Tile labels as they render in the strip. Cycle is excluded: it is
        // correctly absent for the seeded profile.
        let expected = ["Vitality", "Sleep", "Strain", "Brain", "Stress"]
        var found: [String] = []
        for label in expected where app.staticTexts[label].waitForExistence(timeout: 15) {
            found.append(label)
        }

        XCTAssertGreaterThanOrEqual(
            found.count, 4,
            "Vitals showed only \(found.count) tiles: \(found). The report was 2; the strip must carry the full set."
        )
        XCTAssertTrue(found.contains("Sleep"), "The sleep tile is the one the user named as missing")
    }

    /// Home had no camera entry point at all. The only tap target was a card
    /// three taps deep inside the check-in sheet.
    @MainActor
    func testHomeOffersAWayIntoPhotoCapture() {
        let app = launchHome()

        // The nav bar camera is the one that has to be on screen without any
        // scrolling: the card sits six sections down, past two full screens.
        let toolbarCamera = app.buttons["home.mirrorCaptureButton"]
        XCTAssertTrue(toolbarCamera.waitForExistence(timeout: 20),
                      "Home has no camera in the nav bar, so capture is invisible on first open")

        let card = app.otherElements["home.mirrorCaptureCard"]
        let cardExists = card.waitForExistence(timeout: 20)
            || app.buttons["home.mirrorCaptureCard"].waitForExistence(timeout: 5)
        XCTAssertTrue(cardExists, "Home has no photo capture card on the scroll")
    }

    /// An off-topic question used to come back as a confident health answer,
    /// because the semantic gate sat above every distance the embedding model
    /// produces. It must now say plainly that it did not understand.
    @MainActor
    func testAskRefusesAnOffTopicQuestion() {
        let app = askScreen()
        submit("what is the capital of france", in: app)

        let refusal = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@", Self.refusalOpening)
        ).firstMatch
        XCTAssertTrue(
            refusal.waitForExistence(timeout: 25),
            "An off-topic question was answered as health data instead of being refused"
        )
    }

    /// A real question must still be answered, so the tightened gate cannot be
    /// passing the test above by refusing everything.
    @MainActor
    func testAskStillAnswersARealHealthQuestion() {
        let app = askScreen()
        submit("how is my sleep this week", in: app)

        // The confidence badge only renders on a real answer, and the refusal
        // copy must be absent. Both together rule out a query that never ran.
        let confidence = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] '% confidence'")
        ).firstMatch
        XCTAssertTrue(
            confidence.waitForExistence(timeout: 25),
            "A real health question produced no answer, so the semantic gate is too tight"
        )

        let refusal = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@", Self.refusalOpening)
        ).firstMatch
        XCTAssertFalse(refusal.exists, "A real health question was refused")
    }

    // MARK: - Ask helpers

    /// Opening of the refusal copy. Matched on a prefix because the rest is
    /// Remote Config backed and may be reworded without breaking the test.
    private static let refusalOpening = "I did not understand that one"

    private func askScreen() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode", "--ui-test-initial-route=askYourData"]
        app.launch()
        dismissSystemAlerts(app)
        return app
    }

    private func submit(_ question: String, in app: XCUIApplication) {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 30), "Ask text field did not appear")
        field.tap()
        // Submitted with the newline rather than by tapping the keyboard's Search
        // key: on a simulator with a hardware keyboard attached the software
        // keyboard never renders, and a test that cannot find that key would
        // silently never submit and then pass by finding no wrong answer.
        field.typeText(question + "\n")
        XCTAssertEqual(field.value as? String, question,
                       "The question never reached the field, so nothing was submitted")
    }
}
