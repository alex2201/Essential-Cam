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
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testCameraControlsStayFixedWhileDeviceRotates() throws {
#if targetEnvironment(simulator)
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["camera.detectedOrientation"].exists)
        let fixedButtons = ["Settings", "Flash", "Switch capture mode", "Open Photo Library", "Take Photo", "Choose camera lens", "Choose zoom level", "camera.quick.exposure", "camera.quick.focus", "camera.quick.whiteBalance"]
        let initialFrames = fixedButtons.map { app.buttons[$0].frame }
        for (orientation, value) in [
            (UIDeviceOrientation.portrait, "Vertical"),
            (.landscapeLeft, "Horizontal · top to left"),
            (.landscapeRight, "Horizontal · top to right"),
            (.portraitUpsideDown, "Vertical · upside down"),
            (.portrait, "Vertical")
        ] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertLessThan(app.frame.width, app.frame.height, "The interface must stay portrait")
            XCTAssertTrue(app.buttons["Take Photo"].isHittable)
            for (index, name) in fixedButtons.enumerated() {
                XCTAssertEqual(app.buttons[name].frame, initialFrames[index], "Rotating labels must not move \(name)")
            }
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Camera labels · \(value)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].isHittable)
        let settingsAttachment = XCTAttachment(screenshot: app.screenshot())
        settingsAttachment.name = "Settings stays portrait with device horizontal"
        settingsAttachment.lifetime = .keepAlways
        add(settingsAttachment)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
#else
        throw XCTSkip("Simulated orientation changes run in the simulator; verify physical readings on iPhone.")
#endif
    }

    @MainActor
    func testCameraControlsSupportLargeTextInPortrait() throws {
#if targetEnvironment(simulator)
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["camera.detectedOrientation"].exists)
        XCTAssertTrue(app.buttons["Take Photo"].isHittable)

        defer { XCUIDevice.shared.orientation = .portrait }
        for (orientation, value) in [
            (UIDeviceOrientation.portrait, "Vertical"),
            (.landscapeLeft, "Horizontal · top to left"),
            (.landscapeRight, "Horizontal · top to right")
        ] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(app.buttons["Take Photo"].isHittable)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Camera labels large text · \(value)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
#else
        throw XCTSkip("Large-text camera layout is checked in the simulator.")
#endif
    }

    @MainActor
    func testCameraModeOptionsRotateAndApplySelection() throws {
#if targetEnvironment(simulator)
        try verifyCameraModeOptions(largeText: false)
#else
        throw XCTSkip("Physical camera mode changes require manual hardware verification.")
#endif
    }

    @MainActor
    func testCameraModeOptionsRemainReachableWithLargeText() throws {
#if targetEnvironment(simulator)
        try verifyCameraModeOptions(largeText: true)
#else
        throw XCTSkip("Large-text camera submenu layout is checked in the simulator.")
#endif
    }

    @MainActor
    func testCameraModeOptionsPortraitLayout() throws {
#if targetEnvironment(simulator)
        try verifyCameraModeOptions(largeText: true, onlyPortrait: true)
#else
        throw XCTSkip("Portrait submenu layout is checked in the simulator.")
#endif
    }

    @MainActor
    private func verifyCameraModeOptions(largeText: Bool, onlyPortrait: Bool = false) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["camera.detectedOrientation"].exists)
        let positions = [
            (UIDeviceOrientation.landscapeLeft, "Horizontal · top to left"),
            (.landscapeRight, "Horizontal · top to right"),
            (.portraitUpsideDown, "Vertical · upside down"),
            (.portrait, "Vertical")
        ]
        for (orientation, value) in onlyPortrait ? Array(positions.suffix(1)) : positions {
            XCUIDevice.shared.orientation = orientation
            for (quickControl, modeLabel, closeLabel) in [
                ("camera.quick.exposure", "Exposure mode", "Close exposure control"),
                ("camera.quick.focus", "Focus mode", "Close focus control"),
                ("camera.quick.whiteBalance", "White balance mode", "Close white balance control")
            ] {
                app.buttons[quickControl].tap()
                let modeButton = app.buttons[modeLabel]
                XCTAssertTrue(modeButton.waitForExistence(timeout: 5))
                XCTAssertGreaterThanOrEqual(modeButton.frame.height, 44)
                modeButton.tap()
                let automatic = app.buttons["\(modeLabel).Automatic"]
                let manual = app.buttons["\(modeLabel).Manual"]
                XCTAssertTrue(automatic.waitForExistence(timeout: 5))
                XCTAssertTrue(automatic.isHittable)
                XCTAssertTrue(manual.isHittable)
                XCTAssertTrue(app.frame.contains(automatic.frame))
                XCTAssertTrue(app.frame.contains(manual.frame))
                XCTAssertEqual(automatic.value as? String, "Selected")
                XCTAssertLessThan(app.frame.width, app.frame.height)
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = "\(modeLabel) options · \(value) · large text \(largeText)"
                attachment.lifetime = .keepAlways
                add(attachment)
                manual.tap()
                expectation(for: NSPredicate(format: "value == 'Manual'"), evaluatedWith: modeButton)
                waitForExpectations(timeout: 5)
                modeButton.tap()
                XCTAssertTrue(manual.waitForExistence(timeout: 5))
                XCTAssertEqual(manual.value as? String, "Selected")
                automatic.tap()
                expectation(for: NSPredicate(format: "value == 'Automatic'"), evaluatedWith: modeButton)
                waitForExpectations(timeout: 5)
                app.buttons[closeLabel].tap()
                XCTAssertTrue(app.buttons[quickControl].waitForExistence(timeout: 5))
            }
        }
    }

    @MainActor
    func testFlashOptionsRotateAndApplySelection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
        let flash = app.buttons["Flash"]
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown] {
            XCUIDevice.shared.orientation = orientation
            flash.tap()
            for title in ["Auto", "On", "Off"] {
                let option = app.buttons["camera.flash.\(title.lowercased())"]
                XCTAssertTrue(option.waitForExistence(timeout: 3))
                XCTAssertTrue(option.isHittable)
                XCTAssertTrue(app.frame.contains(option.frame))
                if title == "Auto" {
                    let attachment = XCTAttachment(screenshot: app.screenshot())
                    attachment.name = "Flash options \(orientation.rawValue)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                option.tap()
                XCTAssertEqual(flash.value as? String, title)
                XCTAssertFalse(option.exists)
                flash.tap()
                XCTAssertEqual(app.buttons["camera.flash.\(title.lowercased())"].value as? String, "Selected")
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            XCTAssertFalse(app.buttons["camera.flash.off"].exists)
            XCTAssertLessThan(app.frame.width, app.frame.height)
        }
    }

    @MainActor
    func testLensSelectorOpensAndClosesInEveryOrientation() throws {
#if targetEnvironment(simulator)
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["camera.detectedOrientation"].exists)
        for (orientation, value) in [
            (UIDeviceOrientation.landscapeLeft, "Horizontal · top to left"),
            (.landscapeRight, "Horizontal · top to right"),
            (.portraitUpsideDown, "Vertical · upside down"),
            (.portrait, "Vertical")
        ] {
            XCUIDevice.shared.orientation = orientation
            app.buttons["Choose camera lens"].tap()
            let close = app.buttons["Close lens selection"]
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            XCTAssertTrue(close.isHittable)
            XCTAssertTrue(app.buttons["Virtual camera devices"].exists)
            XCTAssertFalse(app.buttons["Virtual camera devices"].isEnabled)
            XCTAssertLessThan(app.frame.width, app.frame.height)
            close.tap()
            XCTAssertTrue(app.buttons["Choose camera lens"].waitForExistence(timeout: 5))
        }
#else
        throw XCTSkip("Simulator checks layout and dismissal; verify physical lens selection on iPhone.")
#endif
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testOnboardingAppearsBeforeCameraAndDoesNotAutomaticallyPrompt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        XCUIDevice.shared.orientation = .portrait
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
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Essential Cam"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testOnboardingSupportsLargeTextInPortrait() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "NO",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Essential Cam"].waitForExistence(timeout: 10))
        let button = app.buttons["onboarding.continue"]
        for _ in 0..<5 {
            if button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.isHittable, "Get Started must remain reachable with large text")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Onboarding large text portrait"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testOnboardingCompletionPersistsAfterRelaunch() throws {
#if targetEnvironment(simulator)
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        XCUIDevice.shared.orientation = .portrait
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
        XCUIDevice.shared.orientation = .portrait
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
        XCUIDevice.shared.orientation = .portrait
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
        XCUIDevice.shared.orientation = .portrait
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
        XCUIDevice.shared.orientation = .portrait
        app.launch()
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

        Thread.sleep(forTimeInterval: 1)
        record.tap()
        let stop = app.buttons["Stop Recording"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10), "Recording must actually start")
        XCTAssertTrue(stop.isEnabled, "Stop must remain usable while other controls are locked")
        XCTAssertFalse(mode.isEnabled)
        XCTAssertFalse(app.buttons["Open Photo Library"].isEnabled)
        Thread.sleep(forTimeInterval: 3)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Video recording portrait"
        attachment.lifetime = .keepAlways
        add(attachment)
        stop.tap()
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        expectation(for: enabled, evaluatedWith: record)
        waitForExpectations(timeout: 20)
        XCTAssertFalse(app.alerts.firstMatch.exists, "Recording and save must complete without an error")
        XCTAssertEqual(app.buttons["Open Photo Library"].value as? String, "Latest capture: Video")
        XCTAssertTrue(mode.isEnabled)

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
            // Return immediately to exercise foreground reconciliation while
            // the clip may still be finalizing or saving.
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
    func testStartupStorageWarningsAllowContinuingBeforeOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "NO",
            "-storageCapacityForTesting", "500000000",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let warning = app.alerts["Low Storage"]
        XCTAssertTrue(warning.waitForExistence(timeout: 10))
        XCTAssertTrue(warning.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "500 MB")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Welcome to Essential Cam"].exists)
        XCTAssertTrue(warning.buttons["Continue"].isHittable)
        warning.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Welcome to Essential Cam"].waitForExistence(timeout: 5))
        XCTAssertFalse(warning.exists)
        app.terminate()
        app.launchArguments = ["-hasCompletedOnboarding", "NO", "-storageCapacityForTesting", "unavailable"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let unavailable = app.alerts["Storage Check Unavailable"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 10))
        unavailable.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Welcome to Essential Cam"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSufficientStartupStorageDoesNotWarn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO", "-storageCapacityForTesting", "1000000000"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Essential Cam"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
