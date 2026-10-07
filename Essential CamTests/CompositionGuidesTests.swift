//
//  CompositionGuidesTests.swift
//  Essential CamTests
//
//  Created by Alexander López.
//

import Foundation
import SwiftUI
import Testing
@testable import Essential_Cam

@MainActor
struct CompositionGuidesTests {
    @Test func defaultsAreDisabledAndYellow() {
        withDefaults { defaults in
            let store = CompositionGuidesStore(defaults: defaults)
            #expect(store.enabled.isEmpty)
            #expect(CompositionGuide.allCases.allSatisfy { store.color(for: $0) == .yellow })
        }
    }

    @Test func independentGuidesAndCustomColorSurviveReload() {
        withDefaults { defaults in
            let store = CompositionGuidesStore(defaults: defaults)
            for guide in CompositionGuide.allCases { store.setEnabled(guide, enabled: true) }
            store.setEnabled(.center, enabled: false)
            let custom = GuideColor(red: 0.12, green: 0.34, blue: 0.56)
            store.setColor(custom, for: .thirds)
            store.setColor(GuideColor(red: 0, green: 0, blue: 1), for: .diagonals)
            let restored = CompositionGuidesStore(defaults: defaults)
            #expect(restored.enabled == Set(CompositionGuide.allCases.filter { $0 != .center }))
            #expect(restored.color(for: .thirds) == custom)
            #expect(restored.color(for: .diagonals) == GuideColor(red: 0, green: 0, blue: 1))
            #expect(restored.color(for: .center) == .yellow)
            restored.setColor(.yellow, for: .thirds)
            let reset = CompositionGuidesStore(defaults: defaults)
            #expect(reset.color(for: .thirds) == .yellow)
            #expect(reset.color(for: .diagonals) == GuideColor(red: 0, green: 0, blue: 1))
        }
    }

    @Test func unknownGuidesAndDamagedColorRecoverSafely() {
        withDefaults { defaults in
            defaults.set(["thirds", "futureGuide"], forKey: "camera.compositionGuides.v1")
            defaults.set(Data("invalid".utf8), forKey: "camera.compositionGuideColor.v1")
            let store = CompositionGuidesStore(defaults: defaults)
            #expect(store.enabled == [.thirds])
            #expect(CompositionGuide.allCases.allSatisfy { store.color(for: $0) == .yellow })
            store.setColor(GuideColor(red: .nan, green: 0, blue: 0), for: .thirds)
            store.setColor(GuideColor(red: 2, green: 0, blue: 0), for: .thirds)
            #expect(CompositionGuide.allCases.allSatisfy { store.color(for: $0) == .yellow })
            defaults.set(try! JSONEncoder().encode(GuideColor(red: -1, green: 0, blue: 0)),
                forKey: "camera.compositionGuideColor.v2.thirds")
            #expect(CompositionGuidesStore(defaults: defaults).color(for: .thirds) == .yellow)
        }
    }

    @Test func sharedColorMigratesWithoutOverwritingIndependentChoices() throws {
        let name = "CompositionGuidesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let oldColor = GuideColor(red: 1, green: 0, blue: 0)
        defaults.set(try JSONEncoder().encode(oldColor), forKey: "camera.compositionGuideColor.v1")
        defaults.set(["thirds", "diagonals"], forKey: "camera.compositionGuides.v1")
        let migrated = CompositionGuidesStore(defaults: defaults)
        #expect(CompositionGuide.allCases.allSatisfy { migrated.color(for: $0) == oldColor })
        #expect(migrated.enabled == [.thirds, .diagonals])
        migrated.setColor(.yellow, for: .thirds)
        let reloaded = CompositionGuidesStore(defaults: defaults)
        #expect(reloaded.color(for: .thirds) == .yellow)
        #expect(reloaded.color(for: .diagonals) == oldColor)
        defaults.set(Data("invalid".utf8), forKey: "camera.compositionGuideColor.v2.diagonals")
        let recovered = CompositionGuidesStore(defaults: defaults)
        #expect(recovered.color(for: .diagonals) == .yellow)
        #expect(recovered.color(for: .center) == oldColor)
    }

    @Test func overlayDrawsSimultaneousGuidesInTheirOwnColors() throws {
        let name = "CompositionGuidesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = CompositionGuidesStore(defaults: defaults)
        store.setEnabled(.thirds, enabled: true)
        store.setEnabled(.diagonals, enabled: true)
        store.setColor(GuideColor(red: 1, green: 0, blue: 0), for: .thirds)
        store.setColor(GuideColor(red: 0, green: 0, blue: 1), for: .diagonals)
        let renderer = ImageRenderer(content: CompositionGuidesOverlay()
            .environment(store)
            .frame(width: 300, height: 400)
            .background(.black))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        var pixels = [UInt8](repeating: 0, count: 300 * 400 * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(data: bytes.baseAddress, width: 300, height: 400,
                bitsPerComponent: 8, bytesPerRow: 300 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 300, height: 400))
        }
        let thirdsPixel = (50 * 300 + 100) * 4
        #expect(pixels[thirdsPixel] > pixels[thirdsPixel + 2])
        let diagonalPixel = (100 * 300 + 75) * 4
        #expect(pixels[diagonalPixel + 2] > pixels[diagonalPixel])
        if let data = renderer.uiImage?.pngData() {
            Attachment.record(data, named: "Independent red thirds and blue diagonals.png")
        }
    }

    @Test func guideGeometryMatchesCompositionAndStaysInsidePreview() {
        #expect(CompositionGuide.thirds.lineSegments.count == 4)
        #expect(CompositionGuide.grid4x4.lineSegments.count == 6)
        #expect(CompositionGuide.center.lineSegments.count == 2)
        #expect(CompositionGuide.diagonals.lineSegments == [
            GuideLineSegment(x1: 0, y1: 0, x2: 1, y2: 1),
            GuideLineSegment(x1: 1, y1: 0, x2: 0, y2: 1)
        ])
        let golden = CompositionGuide.goldenRatio.lineSegments
        #expect(abs(golden[0].x1 - 0.38196601125) < 0.000001)
        #expect(abs(golden[2].x1 - 0.61803398875) < 0.000001)
        for guide in CompositionGuide.allCases {
            for line in guide.lineSegments {
                #expect([line.x1, line.y1, line.x2, line.y2].allSatisfy { (0...1).contains($0) })
            }
        }
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let name = "CompositionGuidesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(defaults)
    }
}
