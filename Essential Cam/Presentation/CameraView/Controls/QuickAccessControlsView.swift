//
//  QuickAccessControlsView.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

import SwiftUI

struct QuickAccessControlsView: View {
    let controls: CameraControlsController
    let showAspectRatioSelector: () -> Void
    let showExposureEditor: () -> Void
    let showFocusEditor: () -> Void
    let showWhiteBalanceEditor: () -> Void

    var body: some View {
        controlsContent
            .cameraControlBackground(cornerRadius: 12)
            .frame(width: 45)
            .padding(.horizontal, 8)
    }

    private var controlsContent: some View {
        VStack(spacing: 8) {
            Button(action: showAspectRatioSelector) {
                VStack(spacing: 4) {
                    Image(systemName: "aspectratio")
                        .font(.system(size: 16, weight: .semibold))
                    Text(controls.settings.aspectRatio.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose aspect ratio")
            .accessibilityValue(controls.settings.aspectRatio.accessibilityName)

            separator

            Button(action: showExposureEditor) {
                VStack(spacing: 4) {
                    Text("EXP")
                        .font(.system(size: 12, weight: .semibold))
                    Text(controls.settings.exposure.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }

            separator

            Button(action: showFocusEditor) {
                VStack(spacing: 4) {
                    Text("AF")
                        .font(.system(size: 12, weight: .semibold))
                    Text(controls.settings.focus.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }

            separator

            Button(action: showWhiteBalanceEditor) {
                VStack(spacing: 4) {
                    Text("WB")
                        .font(.system(size: 12, weight: .semibold))
                    Text(controls.settings.whiteBalance.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(.vertical, 12)
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.35))
            .frame(height: 1)
            .padding(.horizontal, 8)
    }

}

struct AspectRatioSelectionView: View {
    let selectedAspectRatio: CameraAspectRatio
    let selectAspectRatio: (CameraAspectRatio) -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: "aspectratio")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 45, height: 36)
                    .padding(.top, 4)
                    .accessibilityHidden(true)

                ForEach(Array(CameraAspectRatio.allCases.enumerated()), id: \.element) { index, ratio in
                    if index > 0 {
                        Rectangle()
                            .fill(.white.opacity(0.35))
                            .frame(width: 29, height: 1)
                    }

                    Button {
                        selectAspectRatio(ratio)
                    } label: {
                        Text(ratio.displayName)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                ratio == selectedAspectRatio ? Color.yellow : Color.white
                            )
                            .frame(width: 45, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ratio.accessibilityName)
                    .accessibilityAddTraits(
                        ratio == selectedAspectRatio ? .isSelected : []
                    )
                }
            }
            .cameraControlBackground(cornerRadius: 12)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .cameraControlCircleBackground()
            .accessibilityLabel("Close aspect ratio selection")
        }
        .padding(.horizontal, 8)
    }
}
