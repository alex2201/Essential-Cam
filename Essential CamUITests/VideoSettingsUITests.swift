//
//  VideoSettingsUITests.swift
//  Essential CamUITests
//
//  Created by Alexander López.
//

import XCTest

final class VideoSettingsUITests: XCTestCase {
    @MainActor
    func testSettingsAndProfilesInPortrait() throws {
        let app = launch()
        // Edit Video while entering Settings from Photo.
        openSettings(app, profile: "Video")
        let resolution = app.descendants(matching: .any)["video.resolution"].firstMatch
        XCTAssertTrue(resolution.waitForExistence(timeout: 5))
        resolution.tap()
        app.buttons["4K"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))

        openSettings(app, profile: "Photo")
        XCTAssertTrue(app.buttons["settings.Aspect Ratio"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["video.resolution"].exists)
        app.buttons["settings.Timer"].tap()
        app.buttons["10 s"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))

        app.buttons["Switch capture mode"].tap()
        XCTAssertTrue(app.buttons["Record Video"].waitForExistence(timeout: 10))
        // Photo is also editable when entering Settings from Video.
        openSettings(app, profile: "Photo")
        XCTAssertTrue(app.staticTexts["10 s"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Record Video"].waitForExistence(timeout: 10))
        openSettings(app, profile: "Video")
        XCTAssertTrue(app.staticTexts["4K"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Video settings portrait"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testMicrophoneSelectionFromPhotoAndVideo() throws {
        let app = launch()
        openSettings(app, profile: "Video")
        let microphone = app.descendants(matching: .any)["video.microphone"].firstMatch
        for _ in 0..<5 {
            if microphone.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(microphone.isHittable)
        microphone.tap()
        XCTAssertTrue(app.buttons["Automatic"].exists)
        app.buttons["iPhone Microphone"].tap()
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["Done"])
        waitForExpectations(timeout: 10)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
        openSettings(app, profile: "Video")
        for _ in 0..<5 {
            if microphone.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["iPhone Microphone"].exists)
        microphone.tap()
        app.buttons["Automatic"].tap()
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["Done"])
        waitForExpectations(timeout: 10)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testVideoSettingsSupportLargeTextInPortrait() throws {
        let app = launch(largeText: true)
        app.buttons["Switch capture mode"].tap()
        XCTAssertTrue(app.buttons["Record Video"].waitForExistence(timeout: 10))
        openSettings(app)
        let resolution = app.descendants(matching: .any)["video.resolution"].firstMatch
        for _ in 0..<5 {
            if resolution.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(resolution.isHittable)
        resolution.tap()
        XCTAssertTrue(app.buttons["1080p"].exists)
        XCTAssertTrue(app.buttons["4K"].exists)
        app.buttons["1080p"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Video settings large text portrait"
        attachment.lifetime = .keepAlways
        add(attachment)
        let microphone = app.descendants(matching: .any)["video.microphone"].firstMatch
        for _ in 0..<10 {
            if microphone.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(microphone.isHittable)
        microphone.tap()
        XCTAssertTrue(app.buttons["Automatic"].exists)
        XCTAssertTrue(app.buttons["iPhone Microphone"].exists)
        app.buttons["Automatic"].tap()
        app.swipeUp()
        let microphoneAttachment = XCTAttachment(screenshot: app.screenshot())
        microphoneAttachment.name = "Microphone selector large text portrait"
        microphoneAttachment.lifetime = .keepAlways
        add(microphoneAttachment)
    }

    @MainActor
    func testAutomaticMicrophoneRecordingOnDevice() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Recording requires a physical microphone.")
#else
        let app = launch()
        app.buttons["Switch capture mode"].tap()
        let record = app.buttons["Record Video"]
        expectation(for: NSPredicate(format: "exists == true AND enabled == true"), evaluatedWith: record)
        waitForExpectations(timeout: 15)
        openSettings(app)
        let microphone = app.descendants(matching: .any)["video.microphone"].firstMatch
        for _ in 0..<5 {
            if microphone.isHittable { break }
            app.swipeUp()
        }
        microphone.tap()
        app.buttons["Automatic"].tap()
        app.buttons["Done"].tap()
        record.tap()
        let stop = app.buttons["Stop Recording"]
        XCTAssertTrue(stop.waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 2)
        stop.tap()
        expectation(for: NSPredicate(format: "exists == true AND enabled == true"), evaluatedWith: record)
        waitForExpectations(timeout: 30)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertEqual(app.buttons["Open Photo Library"].value as? String, "Latest capture: Video")
#endif
    }

    @MainActor
    func testRecordingWithVideoSettingsOnDevice() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Recording requires a physical camera.")
#else
        let app = launch()
        addUIInterruptionMonitor(withDescription: "Capture permission") { alert in
            for title in ["Allow", "Allow Access to All Photos", "OK"] {
                if alert.buttons[title].exists { alert.buttons[title].tap(); return true }
            }
            return false
        }
        app.buttons["Switch capture mode"].tap()
        let record = app.buttons["Record Video"]
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        if !record.isEnabled { app.tap() }
        XCTAssertTrue(record.isEnabled)
        openSettings(app)
        let resolution = app.descendants(matching: .any)["video.resolution"].firstMatch
        XCTAssertTrue(resolution.exists)
        resolution.tap()
        app.buttons["4K"].tap()
        let fps = app.descendants(matching: .any)["video.frameRate"].firstMatch
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: fps)
        waitForExpectations(timeout: 10)
        fps.tap()
        app.buttons["60 fps"].tap()
        let codec = app.descendants(matching: .any)["video.codec"].firstMatch
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: codec)
        waitForExpectations(timeout: 10)
        codec.tap()
        app.buttons["HEVC (Smaller Files)"].tap()
        let stabilization = app.descendants(matching: .any)["video.stabilization"].firstMatch
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: stabilization)
        waitForExpectations(timeout: 10)
        stabilization.tap()
        app.buttons["Off"].tap()
        let light = app.switches["Continuous Light"]
        if light.exists {
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: light)
            waitForExpectations(timeout: 10)
            // SwiftUI exposes the entire labeled row as a Switch; tap its native child.
            let toggle = light.switches.firstMatch
            XCTAssertTrue(toggle.exists)
            toggle.tap()
            expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: light)
            waitForExpectations(timeout: 10)
        }
        let microphone = app.descendants(matching: .any)["video.microphone"].firstMatch
        for _ in 0..<5 {
            if microphone.isHittable { break }
            app.swipeUp()
        }
        microphone.tap()
        app.buttons["iPhone Microphone"].tap()
        for _ in 0..<5 {
            if app.buttons["settings.Exposure"].isHittable { break }
            app.swipeDown()
        }
        let exposure = app.buttons["settings.Exposure"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: exposure)
        waitForExpectations(timeout: 10)
        exposure.tap()
        app.buttons["Manual"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'ISO'")).firstMatch.exists)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["settings.Focus"].tap()
        XCTAssertTrue(app.buttons["Manual"].isEnabled)
        app.buttons["Manual"].tap()
        XCTAssertTrue(app.sliders.firstMatch.exists)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["settings.White Balance"].tap()
        XCTAssertTrue(app.buttons["Manual"].isEnabled)
        app.buttons["Manual"].tap()
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["4K"].exists)
        XCTAssertTrue(app.staticTexts["60 fps"].exists)
        let settingsAttachment = XCTAttachment(screenshot: app.screenshot())
        settingsAttachment.name = "Physical iPhone video 4K60 HEVC manual exposure"
        settingsAttachment.lifetime = .keepAlways
        add(settingsAttachment)
        app.buttons["Done"].tap()
        record.tap()
        let stop = app.buttons["Stop Recording"]
        XCTAssertTrue(stop.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Switch capture mode"].isEnabled)
        Thread.sleep(forTimeInterval: 3)
        stop.tap()
        let ready = NSPredicate(format: "exists == true AND enabled == true")
        expectation(for: ready, evaluatedWith: record)
        waitForExpectations(timeout: 30)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.buttons["Open Photo Library"].value as? String == "Latest capture: Video")
        app.buttons["Switch capture mode"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
        app.buttons["Take Photo"].tap()
        expectation(for: ready, evaluatedWith: app.buttons["Take Photo"])
        waitForExpectations(timeout: 30)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        openSettings(app)
        XCTAssertTrue(app.staticTexts["Auto, 0.0 EV"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Automatic").count, 2)
        app.buttons["Done"].tap()
#endif
    }

    @MainActor
    private func launch(largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication, profile: String? = nil) {
        let selectedProfile = profile ?? (app.buttons["Record Video"].exists ? "Video" : "Photo")
        let button = app.buttons["Settings"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: button)
        waitForExpectations(timeout: 10)
        button.tap()
        let settingsNavigation = app.navigationBars["Settings"]
        if !settingsNavigation.waitForExistence(timeout: 5), button.exists && button.isHittable {
            // A mode transition can consume the first simulator tap while its overlay settles.
            button.tap()
        }
        XCTAssertTrue(settingsNavigation.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Done"].exists)
        XCTAssertTrue(app.buttons["settings.photo"].exists)
        XCTAssertTrue(app.buttons["settings.video"].exists)
        app.buttons["settings.\(selectedProfile.lowercased())"].tap()
        XCTAssertTrue(app.navigationBars["\(selectedProfile) Settings"].waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["Done"])
        waitForExpectations(timeout: 10)
    }
}
