import XCTest

/// Drives the Daily Mirror capture flow on a simulator, which has no camera.
///
/// The render tests prove each template draws; this proves the screen around
/// them works: that the confirm step opens, that the picker offers more than
/// one look, and that choosing one changes what is on the photo.
final class MirrorCaptureUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(template: String = "fieldNotes") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-test-mode",
            "--ui-test-seed-mirror",
            "--ui-test-mirror-confirm=\(template)"
        ]
        app.launch()
        return app
    }

    /// Home toolbar camera, then the check-in's mirror row, lands on confirm.
    private func openConfirm(_ app: XCUIApplication) {
        let camera = app.buttons.matching(identifier: "camera").firstMatch
        let toolbarCamera = camera.exists ? camera : app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(toolbarCamera.waitForExistence(timeout: 20), "No door into the check-in from Home")
        toolbarCamera.tap()

        // The Daily Mirror row inside the check-in sheet. It says one of two
        // things depending on whether today is already captured, and the seed
        // captures today, so it is the retake wording.
        let mirrorRow = app.staticTexts[Copy_journalCardDone]
        let fallback = app.staticTexts[Copy_journalCardCTA]
        let row = mirrorRow.waitForExistence(timeout: 10) ? mirrorRow : fallback
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The check-in has no Daily Mirror row")
        row.tap()
    }

    // Copy is Remote Config backed, so the tests match on the English defaults
    // that ship in Copy+Mirror.swift rather than importing the app target.
    private let Copy_journalCardDone = "Captured today"
    private let Copy_journalCardCTA = "Capture today's you"

    func testConfirmScreenOffersSeveralTemplates() {
        let app = launch()
        openConfirm(app)

        XCTAssertTrue(app.buttons["Save photo"].waitForExistence(timeout: 15),
                      "Confirm screen did not open")

        // The picker is a row of live previews labelled by template name. At
        // least three must be reachable, or the set has silently gated itself
        // down to nothing on a device with real data.
        let names = ["Field Notes", "The Number", "One Word", "The Slip", "Clean"]
        let found = names.filter { app.buttons[$0].exists || app.staticTexts[$0].exists }
        XCTAssertGreaterThanOrEqual(found.count, 3,
                                    "The picker offered too few templates: \(found)")

        add(screenshot(app, name: "mirror-confirm-field-notes"))
    }

    func testChoosingATemplateChangesThePhoto() {
        let app = launch()
        openConfirm(app)
        XCTAssertTrue(app.buttons["Save photo"].waitForExistence(timeout: 15))

        let before = app.screenshot().pngRepresentation

        // The row is a horizontal scroll and the suggested template leads it,
        // so which cards start on screen depends on the day. Take the first
        // unselected card that can actually be tapped rather than naming one.
        guard let target = firstTappableTemplate(in: app) else {
            return XCTFail("No other template was reachable in the picker")
        }
        target.tap()

        // The preview is a live render, so picking a different look has to
        // change the pixels. Equal screenshots mean the picker is decorative.
        let after = app.screenshot().pngRepresentation
        XCTAssertNotEqual(before, after, "Choosing a template did not change the preview")

        add(screenshot(app, name: "mirror-confirm-slip"))
    }

    /// Saving must write the day and land on the replay rather than failing
    /// silently, which is the one path that loses a photo the user took.
    func testSavingLandsOnTheReplay() {
        let app = launch()
        openConfirm(app)

        let save = app.buttons["Save photo"]
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        save.tap()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 15),
                      "Save did not reach the seven day replay")
        XCTAssertFalse(app.staticTexts["Could not save your photo. Please try again."].exists)

        add(screenshot(app, name: "mirror-replay"))
    }

    /// The first template card that is neither selected nor clipped by the edge
    /// of the scroll view. Scrolls the row once if everything on screen is
    /// already selected or unreachable.
    private func firstTappableTemplate(in app: XCUIApplication) -> XCUIElement? {
        for attempt in 0..<2 {
            let cards = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "mirror.template.")
            )
            for index in 0..<cards.count {
                let card = cards.element(boundBy: index)
                guard card.exists, card.isHittable, !card.isSelected else { continue }
                return card
            }
            if attempt == 0 { app.scrollViews.firstMatch.swipeLeft() }
        }
        return nil
    }

    private func screenshot(_ app: XCUIApplication, name: String) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }
}
