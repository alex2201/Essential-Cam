//
//  CameraFlashButton.swift
//  Essential Cam
//
//  Created by Alexander López on 25/09/26.
//

import SwiftUI

struct CameraFlashButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let controls: CameraControlsController
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            Image(systemName: flashIconName)
                .cameraIconRotation()
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(flashIconColor)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .cameraControlCircleBackground()
        .accessibilityLabel("Flash")
        .accessibilityValue(flashAccessibilityValue)
        .overlay(alignment: .topTrailing) {
            if isExpanded {
                VStack(spacing: 4) {
                    flashOption(.off, title: "Off")
                    flashOption(.automatic, title: "Auto")
                    flashOption(.on, title: "On")
                }
                .padding(4)
                .cameraControlBackground(cornerRadius: 12)
                .offset(y: 52)
                .transition(reduceMotion ? .opacity :
                    .scale(scale: 0.96, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.32), value: isExpanded)
    }

    private func flashOption(
        _ flashMode: CameraFlashMode,
        title: String
    ) -> some View {
        Button {
            isExpanded = false
            controls.setFlashMode(flashMode)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: controls.settings.flashMode == flashMode
                    ? "checkmark.circle.fill" : "circle")
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(controls.settings.flashMode == flashMode ? Color.yellow : Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(width: 52, height: 52)
            .cameraControlContentRotation()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("camera.flash.\(title.lowercased())")
        .accessibilityValue(controls.settings.flashMode == flashMode ? "Selected" : "Not selected")
        .accessibilityAddTraits(controls.settings.flashMode == flashMode ? .isSelected : [])
    }

    private var flashIconName: String {
        switch controls.settings.flashMode {
        case .off:
            "bolt.slash.fill"
        case .automatic:
            "bolt.badge.a.fill"
        case .on:
            "bolt.fill"
        }
    }

    private var flashIconColor: Color {
        switch controls.settings.flashMode {
        case .off:
            .white.opacity(0.75)
        case .automatic:
            .white
        case .on:
            .yellow
        }
    }

    private var flashAccessibilityValue: String {
        switch controls.settings.flashMode {
        case .off:
            "Off"
        case .automatic:
            "Auto"
        case .on:
            "On"
        }
    }
}
