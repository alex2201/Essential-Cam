//
//  VideoCaptureControlsView.swift
//  Essential Cam
//
//  Created by Alexander López on 27/09/26.
//

import SwiftUI

struct VideoCaptureControlsView: View {
    let recordAction: () -> Void
    var isRecording = false
    var isBusy = false
    var indicatorScale: CGFloat = 1

    var body: some View {
        Button(action: recordAction) {
            ZStack {
                Circle().strokeBorder(.white.opacity(0.92), lineWidth: 2)
                RoundedRectangle(cornerRadius: isRecording ? 6 : 28)
                    .fill(.red)
                    .frame(width: isRecording ? 28 : 56, height: isRecording ? 28 : 56)
                    .scaleEffect(indicatorScale)
                if isBusy { ProgressView().tint(.white) }
            }
            .frame(width: 72, height: 72)
            .contentShape(Circle())
        }
        .buttonStyle(CaptureButtonStyle())
        .captureButtonBackground()
        .accessibilityLabel(isRecording ? "Stop Recording" : "Record Video")
        .accessibilityHint(isRecording ? "Finishes and saves your video" : "Starts video recording with audio")
        .accessibilityValue(isRecording ? "Recording" : isBusy ? "Please wait" : "Ready")
    }
}
