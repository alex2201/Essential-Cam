//
//  CompositionGuidesStore.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Foundation
import Observation

@MainActor
@Observable
final class CompositionGuidesStore {
    private let defaults: UserDefaults
    private static let guidesKey = "camera.compositionGuides.v1"
    private static let legacyColorKey = "camera.compositionGuideColor.v1"
    private static func colorKey(for guide: CompositionGuide) -> String {
        "camera.compositionGuideColor.v2.\(guide.rawValue)"
    }

    private(set) var enabled: Set<CompositionGuide>
    private(set) var colors: [CompositionGuide: GuideColor]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = Set((defaults.stringArray(forKey: Self.guidesKey) ?? []).compactMap(CompositionGuide.init(rawValue:)))
        let legacyColor = Self.loadColor(defaults.data(forKey: Self.legacyColorKey)) ?? .yellow
        colors = Dictionary(uniqueKeysWithValues: CompositionGuide.allCases.map { guide in
            let key = Self.colorKey(for: guide)
            let color: GuideColor
            if defaults.object(forKey: key) != nil {
                color = Self.loadColor(defaults.data(forKey: key)) ?? .yellow
            } else {
                color = legacyColor
                // Migrate each guide independently, preserving the previous shared color.
                if let data = try? JSONEncoder().encode(color) { defaults.set(data, forKey: key) }
            }
            return (guide, color)
        })
    }

    func setEnabled(_ guide: CompositionGuide, enabled isEnabled: Bool) {
        if isEnabled { enabled.insert(guide) } else { enabled.remove(guide) }
        defaults.set(CompositionGuide.allCases.filter { enabled.contains($0) }.map(\.rawValue), forKey: Self.guidesKey)
    }

    func color(for guide: CompositionGuide) -> GuideColor {
        colors[guide] ?? .yellow
    }

    func setColor(_ newColor: GuideColor, for guide: CompositionGuide) {
        guard newColor.isValid, let data = try? JSONEncoder().encode(newColor) else { return }
        colors[guide] = newColor
        defaults.set(data, forKey: Self.colorKey(for: guide))
    }

    private static func loadColor(_ data: Data?) -> GuideColor? {
        guard let data, let color = try? JSONDecoder().decode(GuideColor.self, from: data),
              color.isValid else { return nil }
        return color
    }
}
