//
//  Essential_CamTests.swift
//  Essential CamTests
//
//  Created by Alexander López on 01/09/26.
//

import Foundation
import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers
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

    @Test func pngExportBakesOrientationIntoPixelsWithoutRotatingMetadata() throws {
        let sourceData = try makeJPEG(width: 4, height: 2, orientation: .right)

        let pngData = try PhotoCropper.process(
            sourceData,
            to: .fourByThree,
            outputFormat: .png
        )

        let source = try #require(CGImageSourceCreateWithData(pngData as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )

        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(height > width)
        #expect(properties[kCGImagePropertyOrientation] as? UInt32 == CGImagePropertyOrientation.up.rawValue)
    }

    private func makeJPEG(
        width: Int,
        height: Int,
        orientation: CGImagePropertyOrientation
    ) throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(
                data,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        )
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
        )
        #expect(CGImageDestinationFinalize(destination))

        return data as Data
    }

}
