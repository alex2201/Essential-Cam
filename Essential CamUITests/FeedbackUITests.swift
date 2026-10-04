//
//  FeedbackUITests.swift
//  Essential CamUITests
//
//  Created by Alexander López.
//

import XCTest

final class FeedbackUITests: XCTestCase {
    @MainActor
    func testFeedbackNavigationAndEditing() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
        ]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        openFeedback(in: app)

        let message = app.descendants(matching: .any)["feedback.message"].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()
        message.typeText("Please add a new camera feature.\nThank you!")
        XCTAssertEqual(message.value as? String, "Please add a new camera feature.\nThank you!")
        XCTAssertTrue(app.buttons["feedback.send"].isEnabled)
        app.navigationBars["Feedback"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFeedbackSupportsLargeTextInPortrait() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        openFeedback(in: app)

        Thread.sleep(forTimeInterval: 1)
        let message = app.descendants(matching: .any)["feedback.message"].firstMatch
        scrollForm(in: app, upward: false)
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.isHittable)
        for _ in 0..<8 {
            if app.buttons["feedback.send"].isHittable { break }
            scrollForm(in: app, upward: true)
        }
        XCTAssertTrue(app.buttons["feedback.send"].exists)
        XCTAssertFalse(app.buttons["feedback.send"].isEnabled)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Feedback large text portrait"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testFeedbackFailurePreservesMessageAndRetrySucceeds() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launchEnvironment["feedbackResponseForTesting"] = "retry"
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        openFeedback(in: app)
        let message = app.descendants(matching: .any)["feedback.message"].firstMatch
        let send = app.buttons["feedback.send"]
        XCTAssertFalse(send.isEnabled)
        message.tap()
        message.typeText("Keep my message on failure.")
        tapSend(in: app)
        let failure = app.alerts["Couldn't Send Feedback"]
        XCTAssertTrue(failure.waitForExistence(timeout: 10))
        failure.buttons["Cancel"].tap()
        XCTAssertEqual(message.value as? String, "Keep my message on failure.")
        XCTAssertTrue(send.isEnabled)
        tapSend(in: app)
        let success = app.alerts["Feedback Sent"]
        XCTAssertTrue(success.waitForExistence(timeout: 10))
        success.buttons["OK"].tap()
        XCTAssertFalse(send.isEnabled)
        XCTAssertNotEqual(message.value as? String, "Keep my message on failure.")
    }

    @MainActor
    private func tapSend(in app: XCUIApplication) {
        // Dismiss the keyboard before reaching the form's send row.
        scrollForm(in: app, upward: true)
        for _ in 0..<8 {
            if app.buttons["feedback.send"].isHittable { break }
            scrollForm(in: app, upward: true)
        }
        XCTAssertTrue(app.buttons["feedback.send"].isHittable)
        app.buttons["feedback.send"].tap()
    }

    @MainActor
    private func scrollForm(in app: XCUIApplication, upward: Bool) {
        // Drag in the form's margin so the multiline field doesn't consume the gesture.
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.25))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.85))
        (upward ? bottom : top).press(forDuration: 0.05, thenDragTo: upward ? top : bottom)
    }

    @MainActor
    private func openFeedback(in app: XCUIApplication) {
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let feedback = app.buttons["Feedback"]
        for _ in 0..<12 {
            if feedback.isHittable { break }
            scrollForm(in: app, upward: true)
        }
        XCTAssertTrue(feedback.isHittable)
        feedback.tap()
        XCTAssertTrue(app.navigationBars["Feedback"].waitForExistence(timeout: 5))
    }
}
