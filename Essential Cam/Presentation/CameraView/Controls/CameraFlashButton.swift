//
//  CameraFlashButton.swift
//  Essential Cam
//
//  Created by Codex on 25/09/26.
//

import SwiftUI

struct CameraFlashButton: View {
    let controls: CameraControlsController

    var body: some View {
        Menu {
            flashOption(.off, title: "Off")
            flashOption(.automatic, title: "Auto")
            flashOption(.on, title: "On")
        } label: {
            Image(systemName: flashIconName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(flashIconColor)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .cameraControlCircleBackground()
        .accessibilityLabel("Flash")
        .accessibilityValue(flashAccessibilityValue)
    }

    private func flashOption(
        _ flashMode: CameraFlashMode,
        title: String
    ) -> some View {
        Button {
            controls.setFlashMode(flashMode)
        } label: {
            if controls.settings.flashMode == flashMode {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
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
