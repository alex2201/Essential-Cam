//
//  VideoCaptureControlsView.swift
//  Essential Cam
//
//  Created by Codex on 27/09/26.
//

import SwiftUI

struct VideoCaptureControlsView: View {
    let recordAction: () -> Void
    var indicatorScale: CGFloat = 1

    var body: some View {
        Button(action: recordAction) {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.92), lineWidth: 2)

                Circle()
                    .fill(.red)
                    .padding(8)
                    .scaleEffect(indicatorScale)
            }
            .frame(width: 72, height: 72)
            .contentShape(Circle())
        }
        .buttonStyle(CaptureButtonStyle())
        .captureButtonBackground()
        .accessibilityLabel("Record Video")
        .accessibilityHint("Starts video recording")
    }
}
