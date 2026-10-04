//
//  Essential_CamUITests.swift
//  Essential CamUITests
//
//  Created by Alexander López on 01/09/26.
//

import XCTest

final class Essential_CamUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testOnboardingAppearsBeforeCameraAndDoesNotAutomaticallyPrompt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Essential Cam"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Take Photo"].exists)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(system.alerts.firstMatch.exists)
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["Your camera, ready."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Take Photo"].exists)
        XCTAssertFalse(system.alerts.firstMatch.exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Essential Cam"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testOnboardingSupportsLargeTextAndLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "NO",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.staticTexts["Welcome to Essential Cam"].waitForExistence(timeout: 10))
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            // Wait for the rotation animation before inspecting the layout or
            // taking a screenshot; accessibility can update before rendering.
            Thread.sleep(forTimeInterval: 1)
            let button = app.buttons["onboarding.continue"]
            for _ in 0..<5 {
                if button.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(button.isHittable, "Get Started must remain reachable with large text")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Onboarding large text \(orientation.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testOnboardingCompletionPersistsAfterRelaunch() throws {
#if targetEnvironment(simulator)
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Essential Cam"].waitForExistence(timeout: 10))
        app.buttons["onboarding.continue"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Your camera, ready.", "Keep your captures.", "Sound for your videos."] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
            let button = app.buttons["onboarding.continue"]
            let ready = NSPredicate(format: "enabled == true")
            expectation(for: ready, evaluatedWith: button)
            waitForExpectations(timeout: 5)
            if button.label == "Allow Access" {
                button.tap()
                if system.alerts.firstMatch.waitForExistence(timeout: 3) {
                    let alert = system.alerts.firstMatch
                    let deny = alert.buttons.matching(NSPredicate(
                        format: "label IN %@", ["Don't Allow", "Don’t Allow", "No permitir", "No Permitir"]
                    )).firstMatch
                    XCTAssertTrue(deny.exists, "Permission dialog must offer declining access")
                    deny.tap()
                }
                expectation(for: ready, evaluatedWith: button)
                waitForExpectations(timeout: 5)
                XCTAssertNotEqual(button.label, "Allow Access")
            }
            button.tap()
        }
        app.terminate()
        // The launch argument overrides persisted defaults while this process
        // runs. Remove it to verify the value saved by Open Camera.
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Welcome to Essential Cam"].exists)
#else
        throw XCTSkip("Permission denial regression runs in the simulator to preserve device permissions.")
#endif
    }

    @MainActor
    func testCompletedOnboardingOpensCamera() throws {
#if targetEnvironment(simulator)
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Welcome to Essential Cam"].exists)
#else
        throw XCTSkip("Camera authorization needs hardware interaction.")
#endif
    }

    @MainActor
    func testVideoModeChecksPermissionsAndAllowsReturningToPhoto() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Camera interaction requires the physical test iPhone.")
#else
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        let mode = app.buttons["Switch capture mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        XCTAssertEqual(mode.value as? String, "Photo")
        mode.tap()

        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let record = app.buttons["Record Video"]
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            let systemAlert = system.alerts.firstMatch
            if systemAlert.exists {
                for label in ["Allow", "OK", "Allow Photos to Be Added", "Allow Access to All Photos"] {
                    let button = systemAlert.buttons[label]
                    if button.exists {
                        button.tap()
                        break
                    }
                }
            }
            if app.alerts.firstMatch.exists || (record.exists && record.isEnabled) { break }
            Thread.sleep(forTimeInterval: 0.2)
        }

        XCTAssertEqual(mode.value as? String, "Video")
        if app.alerts.firstMatch.exists {
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.buttons["Open Settings"].exists)
            XCTAssertFalse(record.isEnabled)
            alert.buttons["Cancel"].tap()
        } else {
            XCTAssertTrue(record.exists && record.isEnabled, "Video permissions should finish checking")
        }
        XCTAssertTrue(mode.isEnabled)
        mode.tap()
        XCTAssertEqual(mode.value as? String, "Photo")
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 3))
#endif
    }

    @MainActor
    func testBasicVideoRecordsSavesAndPlaysOnDevice() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Video capture requires camera and microphone hardware.")
#else
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        let mode = app.buttons["Switch capture mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 20))

        // Request read access so the saved clip can be verified in the gallery.
        app.buttons["Open Photo Library"].tap()
        allowCapturePermissionAlerts()
        XCTAssertTrue(app.navigationBars["Gallery"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        mode.tap()
        allowCapturePermissionAlerts()
        let record = app.buttons["Record Video"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: record)
        waitForExpectations(timeout: 15)

        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            Thread.sleep(forTimeInterval: 1)
            record.tap()
            let stop = app.buttons["Stop Recording"]
            XCTAssertTrue(stop.waitForExistence(timeout: 10), "Recording must actually start")
            XCTAssertTrue(stop.isEnabled, "Stop must remain usable while other controls are locked")
            XCTAssertFalse(mode.isEnabled)
            XCTAssertFalse(app.buttons["Open Photo Library"].isEnabled)
            Thread.sleep(forTimeInterval: 3)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "Video recording \(orientation.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
            stop.tap()
            XCTAssertTrue(record.waitForExistence(timeout: 10))
            expectation(for: enabled, evaluatedWith: record)
            waitForExpectations(timeout: 20)
            XCTAssertFalse(app.alerts.firstMatch.exists, "Recording and save must complete without an error")
            XCTAssertEqual(app.buttons["Open Photo Library"].value as? String, "Latest capture: Video")
            XCTAssertTrue(mode.isEnabled)
        }

        // Also check front-camera recording and finalization when backgrounded.
        XCUIDevice.shared.orientation = .portrait
        let switchCamera = app.buttons["Switch between front and back camera"]
        if switchCamera.exists && switchCamera.isEnabled {
            switchCamera.tap()
            expectation(for: enabled, evaluatedWith: record)
            waitForExpectations(timeout: 15)
            record.tap()
            XCTAssertTrue(app.buttons["Stop Recording"].waitForExistence(timeout: 10))
            Thread.sleep(forTimeInterval: 3)
            XCUIDevice.shared.press(.home)
            Thread.sleep(forTimeInterval: 3)
            app.activate()
            XCTAssertTrue(record.waitForExistence(timeout: 20))
            expectation(for: enabled, evaluatedWith: record)
            waitForExpectations(timeout: 20)
            XCTAssertFalse(app.alerts.firstMatch.exists)
            XCTAssertEqual(app.buttons["Open Photo Library"].value as? String, "Latest capture: Video")
            switchCamera.tap()
            expectation(for: enabled, evaluatedWith: record)
            waitForExpectations(timeout: 15)
        }

        app.buttons["Open Photo Library"].tap()
        XCTAssertTrue(app.navigationBars["Gallery"].waitForExistence(timeout: 10))
        let play = app.buttons["Play video"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 10), "A video thumbnail must expose the play action")
        play.tap()
        XCTAssertTrue(app.navigationBars["Video"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 2)
        let playbackAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        playbackAttachment.name = "Recorded video playback"
        playbackAttachment.lifetime = .keepAlways
        add(playbackAttachment)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Gallery"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        mode.tap()
        XCTAssertEqual(mode.value as? String, "Photo")
        let photo = app.buttons["Take Photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        expectation(for: enabled, evaluatedWith: photo)
        waitForExpectations(timeout: 15)
        photo.tap()
        let latestPhoto = NSPredicate(format: "value == %@", "Latest capture: Photo")
        expectation(for: latestPhoto, evaluatedWith: app.buttons["Open Photo Library"])
        waitForExpectations(timeout: 30)
        XCTAssertFalse(app.alerts.firstMatch.exists, "Photo capture must still save after video")
#endif
    }

    @MainActor
    private func allowCapturePermissionAlerts() {
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<4 {
            let alert = system.alerts.firstMatch
            guard alert.waitForExistence(timeout: 2) else { return }
            let labels = ["Allow", "OK", "Allow Photos to Be Added", "Allow Access to All Photos", "Allow Full Access", "Permitir", "Aceptar", "Permitir acceso a todas las fotos", "Permitir acceso completo"]
            let allow = alert.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
            guard allow.exists else { return }
            allow.tap()
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
