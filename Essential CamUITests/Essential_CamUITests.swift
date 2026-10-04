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
    func testVideoModeChecksPermissionsAndAllowsReturningToPhoto() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Camera interaction requires the physical test iPhone.")
#else
        let app = XCUIApplication()
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
