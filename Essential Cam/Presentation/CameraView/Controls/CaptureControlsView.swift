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
    var indicatorScale: CGFloat = 1

    var body: some View {
        Button(action: captureAction) {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.92), lineWidth: 2)

                Circle()
                    .fill(.white)
                    .padding(8)
                    .scaleEffect(indicatorScale)
            }
            .frame(width: 72, height: 72)
            .contentShape(Circle())
        }
        .buttonStyle(CaptureButtonStyle())
        .captureButtonBackground()
        .disabled(isCaptureDisabled)
        .opacity(isCaptureDisabled ? 0.58 : 1)
        .animation(.easeOut(duration: 0.18), value: isCaptureDisabled)
        .accessibilityLabel("Take Photo")
        .accessibilityHint("Captures a photo")
    }
}

struct CaptureButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(
                .spring(response: 0.22, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}

extension View {
    @ViewBuilder
    func captureButtonBackground() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(
                .regular
                    .tint(.black.opacity(0.22))
                    .interactive(),
                in: .circle
            )
        } else {
            background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(.black.opacity(0.18))
                    }
            }
        }
    }
}
