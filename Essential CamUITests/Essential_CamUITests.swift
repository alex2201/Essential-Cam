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
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
