import XCTest

/// Runtime proof for two reports the user raised: Ask answering the wrong
/// question, and the photo capture having no way in from Home.
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

    /// Home had no camera entry point at all. The only tap target was a card
    /// three taps deep inside the check-in sheet.
    @MainActor
    func testHomeOffersAWayIntoPhotoCapture() {
        let app = launchHome()

        // The nav bar camera is the one door into capture now that Home is the
        // brief, so it has to be on screen without any scrolling.
        let toolbarCamera = app.buttons["home.mirrorCaptureButton"]
        XCTAssertTrue(toolbarCamera.waitForExistence(timeout: 20),
                      "Home has no camera in the nav bar, so capture is invisible on first open")
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
