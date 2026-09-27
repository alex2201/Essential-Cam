//
//  CaptureModeSelector.swift
//  Essential Cam
//
//  Created by Codex on 27/09/26.
//

import SwiftUI

extension CaptureMode {
    var iconName: String {
        switch self {
        case .photo:
            "camera.fill"
        case .video:
            "video.fill"
        }
    }

    var accessibilityName: String {
        switch self {
        case .photo:
            "Photo"
        case .video:
            "Video"
        }
    }
}

struct CaptureModeButton: View {
    @Binding var selectedMode: CaptureMode

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedMode = selectedMode == .photo ? .video : .photo
            }
        } label: {
            Image(systemName: selectedMode.iconName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .cameraControlCircleBackground()
        .accessibilityLabel("Switch capture mode")
        .accessibilityValue(selectedMode.accessibilityName)
        .accessibilityHint("Changes between photo and video")
    }
}
