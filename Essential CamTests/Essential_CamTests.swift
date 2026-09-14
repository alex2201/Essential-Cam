//
//  Essential_CamTests.swift
//  Essential CamTests
//
//  Created by Alexander López on 01/09/26.
//

import Foundation
import Testing
@testable import Essential_Cam

struct Essential_CamTests {

    @Test func cameraSettingsRoundTripThroughJSON() throws {
        let settings = CameraSettings(
            exposure: .manual(iso: 400, durationInSeconds: 1.0 / 125.0),
            focus: .manual(lensPosition: 0.75),
            whiteBalance: .manual(temperature: 5_600, tint: 10),
            zoomFactor: 2,
            captureMode: .photo,
            aspectRatio: .fourByThree,
            flashMode: .automatic
        )

        let data = try JSONEncoder().encode(settings)
        let decodedSettings = try JSONDecoder().decode(CameraSettings.self, from: data)

        #expect(decodedSettings == settings)
    }

}
