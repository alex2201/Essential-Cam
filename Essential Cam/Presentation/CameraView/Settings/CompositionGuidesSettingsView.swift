//
//  CompositionGuidesSettingsView.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import SwiftUI
import UIKit

struct CompositionGuidesSettingsView: View {
    @Environment(CompositionGuidesStore.self) private var store

    var body: some View {
        Form {
            Section {
                Text("Enable any combination and choose a color for each guide. Guides appear only in the camera preview, in both Photo and Video.")
            }
            ForEach(CompositionGuide.allCases, id: \.self) { guide in
                Section(guide.displayName) {
                    Toggle("Enabled", isOn: Binding(
                        get: { store.enabled.contains(guide) },
                        set: { store.setEnabled(guide, enabled: $0) }
                    ))
                    .accessibilityLabel(guide.displayName)
                    .accessibilityIdentifier("guides.\(guide.rawValue)")
                    ColorPicker("Color", selection: Binding(
                        get: { store.color(for: guide).swiftUIColor },
                        set: { selected in
                            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                            guard UIColor(selected).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return }
                            store.setColor(GuideColor(red: Double(red), green: Double(green), blue: Double(blue)), for: guide)
                        }
                    ), supportsOpacity: false)
                    .accessibilityLabel("\(guide.displayName) Color")
                    .accessibilityIdentifier("guides.color.\(guide.rawValue)")
                    Button("Reset") { store.setColor(.yellow, for: guide) }
                        .accessibilityLabel("Reset \(guide.displayName) Color to Yellow")
                        .accessibilityIdentifier("guides.resetColor.\(guide.rawValue)")
                }
            }
            Section("Preview") {
                CompositionGuidesOverlay()
                    .aspectRatio(3.0 / 4, contentMode: .fit)
                    .background(.gray)
                    .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("Composition Guides")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension CompositionGuide {
    var displayName: String {
        switch self {
        case .thirds: "Rule of Thirds (3×3)"
        case .center: "Center"
        case .grid4x4: "Grid (4×4)"
        case .goldenRatio: "Golden Ratio"
        case .diagonals: "Diagonals"
        }
    }
}
