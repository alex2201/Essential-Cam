//
//  CompositionGuidesOverlay.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import SwiftUI

struct CompositionGuidesOverlay: View {
    @Environment(CompositionGuidesStore.self) private var store

    var body: some View {
        let enabled = store.enabled
        let colors = store.colors
        Canvas { context, size in
            for guide in CompositionGuide.allCases where enabled.contains(guide) {
                var path = Path()
                for line in guide.lineSegments {
                    path.move(to: CGPoint(x: line.x1 * size.width, y: line.y1 * size.height))
                    path.addLine(to: CGPoint(x: line.x2 * size.width, y: line.y2 * size.height))
                }
                let color = (colors[guide] ?? .yellow).swiftUIColor
                context.stroke(path, with: .color(.black.opacity(0.4)), lineWidth: 2)
                context.stroke(path, with: .color(color), lineWidth: 1)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension GuideColor {
    var swiftUIColor: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}
