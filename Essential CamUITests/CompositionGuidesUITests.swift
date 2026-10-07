//
//  CompositionGuidesUITests.swift
//  Essential CamUITests
//
//  Created by Alexander López.
//

import XCTest

final class CompositionGuidesUITests: XCTestCase {
    @MainActor
    func testGuidesCanBeCombinedAndRetainedInPhotoAndVideo() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        openGuides(app)
        let identifiers = ["thirds", "center", "grid4x4", "goldenRatio", "diagonals"]
        for identifier in identifiers {
            let toggle = app.switches["guides.\(identifier)"]
            reveal(toggle, in: app)
            XCTAssertTrue(app.descendants(matching: .any)["guides.color.\(identifier)"].firstMatch.exists)
            if toggle.value as? String != "1" { toggle.switches.firstMatch.tap() }
            XCTAssertEqual(toggle.value as? String, "1")
        }
        let center = app.switches["guides.center"]
        reveal(center, in: app, upwards: false)
        center.switches.firstMatch.tap()
        XCTAssertEqual(center.value as? String, "0")
        let thirds = app.switches["guides.thirds"]
        reveal(thirds, in: app, upwards: false)
        XCTAssertEqual(thirds.value as? String, "1")
        app.buttons["guides.resetColor.thirds"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
        let previewAttachment = XCTAttachment(screenshot: app.screenshot())
        previewAttachment.name = "Combined composition guides photo portrait"
        previewAttachment.lifetime = .keepAlways
        add(previewAttachment)
        app.buttons["Switch capture mode"].tap()
        XCTAssertTrue(app.buttons["Record Video"].waitForExistence(timeout: 10))
        openGuides(app)
        reveal(app.switches["guides.center"], in: app)
        XCTAssertEqual(app.switches["guides.center"].value as? String, "0")
        reveal(app.switches["guides.thirds"], in: app, upwards: false)
        XCTAssertEqual(app.switches["guides.thirds"].value as? String, "1")
        app.terminate()
        app.launch()
        openGuides(app)
        for identifier in identifiers {
            reveal(app.switches["guides.\(identifier)"], in: app)
            XCTAssertEqual(app.switches["guides.\(identifier)"].value as? String, identifier == "center" ? "0" : "1")
        }
        // Restore the disabled default after validating persistence.
        reveal(app.switches["guides.thirds"], in: app, upwards: false)
        for identifier in identifiers where identifier != "center" {
            reveal(app.switches["guides.\(identifier)"], in: app)
            app.switches["guides.\(identifier)"].switches.firstMatch.tap()
        }
    }

    @MainActor
    func testGuidesSettingsSupportLargeText() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openGuides(app)
        for identifier in ["thirds", "center", "grid4x4", "goldenRatio", "diagonals"] {
            let toggle = app.switches["guides.\(identifier)"]
            reveal(toggle, in: app)
            let color = app.descendants(matching: .any)["guides.color.\(identifier)"].firstMatch
            reveal(color, in: app)
            let reset = app.buttons["guides.resetColor.\(identifier)"]
            reveal(reset, in: app)
            reset.tap()
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Composition guides large text portrait"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = true) {
        for _ in 0..<15 {
            if element.isHittable { break }
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func openGuides(_ app: XCUIApplication) {
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: settings)
        waitForExpectations(timeout: 15)
        settings.tap()
        let guides = app.buttons["settings.guides"]
        if !guides.waitForExistence(timeout: 5), settings.isHittable { settings.tap() }
        XCTAssertTrue(guides.waitForExistence(timeout: 10))
        guides.tap()
        XCTAssertTrue(app.navigationBars["Composition Guides"].waitForExistence(timeout: 10))
    }
}
