//
//  CaptureControlsView.swift
//  Essential Cam
//

import SwiftUI

struct CaptureControlsView: View {
    let captureAction: () -> Void
    let isCaptureDisabled: Bool

    var body: some View {
        ZStack(alignment: .center) {
            Color.clear

            Button(action: captureAction) {
                Circle()
                    .fill()
                    .foregroundStyle(.red)
                    .frame(width: 40, height: 40)
            }
            .disabled(isCaptureDisabled)
        }
    }
}
