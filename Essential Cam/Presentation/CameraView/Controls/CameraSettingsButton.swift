//
//  CameraSettingsButton.swift
//  Essential Cam
//
//  Updated by Alexander López on 05/10/26.
//

import SwiftUI

struct CameraSettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .cameraIconRotation()
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .cameraControlCircleBackground()
        .accessibilityLabel("Settings")
    }
}
