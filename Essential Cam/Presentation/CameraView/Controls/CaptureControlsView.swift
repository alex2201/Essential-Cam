//
//  CaptureControlsView.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

import SwiftUI

struct CaptureControlsView: View {
    let captureAction: () -> Void
    let isCaptureDisabled: Bool

    var body: some View {
        Button(action: captureAction) {
            Circle()
                .fill()
                .foregroundStyle(.red)
                .frame(width: 40, height: 40)
        }
        .disabled(isCaptureDisabled)
        .accessibilityLabel("Take Photo")
    }
}
