//
//  CameraOrientationTests.swift
//  Essential CamTests
//
//  Created by Alexander López on 05/10/26.
//

import SwiftUI
import Testing
import UIKit
@testable import Essential_Cam

@MainActor
struct CameraOrientationTests {
    @Test(arguments: [0.0, 90.0, -90.0, 180.0])
    func lensSelectorFocalLengthLayout(degrees: Double) throws {
        let cameras = [13.0, 24.0, 77.0].enumerated().map { index, focalLength in
            Camera(id: "lens-\(index)", name: "Test camera", position: .back,
                lens: .wideAngle, deviceKind: .physical, displayZoomFactor: Double(index + 1),
                nominalFocalLengthIn35mmFilm: focalLength)
        }
        let renderer = ImageRenderer(content:
            LensSelectionView(physicalCameras: cameras, virtualCamera: nil,
                selectedCamera: nil, selectCamera: { _ in }, dismiss: {})
                .environment(\.cameraIconRotationDegrees, degrees)
                .environment(\.dynamicTypeSize, .accessibility5)
                .frame(width: 90, height: 320)
                .background(.black)
        )
        renderer.scale = 3
        let image = try #require(renderer.uiImage)
        let data = try #require(image.pngData())
        Attachment.record(data, named: "Lens focal lengths \(degrees) degrees.png")
    }

    @Test func controlAnglesCompensateAllDevicePositions() {
        #expect(CaptureOrientation.portrait.controlRotationDegrees == 0)
        #expect(CaptureOrientation.landscapeLeft.controlRotationDegrees == 90)
        #expect(CaptureOrientation.landscapeRight.controlRotationDegrees == -90)
        #expect(CaptureOrientation.portraitUpsideDown.controlRotationDegrees == 180)
    }

    @Test func controlsOutsideCameraDefaultToNoRotation() {
        #expect(EnvironmentValues().cameraIconRotationDegrees == 0)
    }

    @Test func detectsAllFourPositionsIncludingTransitionsBetweenSides() {
        let controller = CameraOrientationController()
        let readings: [(UIDeviceOrientation, CaptureOrientation)] = [
            (.portrait, .portrait),
            (.landscapeLeft, .landscapeLeft),
            (.landscapeRight, .landscapeRight),
            (.portraitUpsideDown, .portraitUpsideDown),
            (.portrait, .portrait)
        ]
        for (reading, expected) in readings {
            controller.update(reading)
            #expect(controller.orientation == expected)
        }
    }

    @Test func flatAndUnknownReadingsDoNotInventAnInitialOrientation() {
        let controller = CameraOrientationController()
        for reading in [UIDeviceOrientation.unknown, .faceUp, .faceDown] {
            controller.update(reading)
            #expect(controller.orientation == nil)
        }
    }

    @Test func flatAndUnknownReadingsKeepTheLastValidPosition() {
        let controller = CameraOrientationController()
        controller.update(.portraitUpsideDown)
        for reading in [UIDeviceOrientation.faceUp, .faceDown, .unknown] {
            controller.update(reading)
            #expect(controller.orientation == .portraitUpsideDown)
        }
        controller.update(.landscapeRight)
        #expect(controller.orientation == .landscapeRight)
    }
}
