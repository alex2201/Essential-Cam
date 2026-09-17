//
//  QuickAccessControlsView.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

import SwiftUI

struct QuickAccessControlsView: View {
    let controls: CameraControlsController
    let showExposureEditor: () -> Void
    let showFocusEditor: () -> Void
    let showWhiteBalanceEditor: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                controlsContent
                    .glassEffect(
                        .regular
                            .tint(.black.opacity(0.35))
                            .interactive(),
                        in: .rect(cornerRadius: 12)
                    )
            } else {
                controlsContent
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.55))
                    }
            }
        }
        .frame(width: 45)
        .padding(.horizontal, 8)
    }

    private var controlsContent: some View {
        VStack(spacing: 8) {
            Menu {
                ForEach(CameraAspectRatio.allCases, id: \.self) { ratio in
                    Button {
                        controls.setAspectRatio(ratio)
                    } label: {
                        settingLabel(
                            ratio.displayName,
                            isSelected: ratio == controls.settings.aspectRatio
                        )
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Text("FMT")
                        .font(.system(size: 12, weight: .semibold))
                    Text(controls.settings.aspectRatio.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }

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

            separator

            Menu {
                flashMenu
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More camera settings")
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
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

    private var flashMenu: some View {
        Menu("Flash") {
            Button {
                controls.setFlashMode(.off)
            } label: {
                settingLabel("Off", isSelected: controls.settings.flashMode == .off)
            }

            Button {
                controls.setFlashMode(.automatic)
            } label: {
                settingLabel("Auto", isSelected: controls.settings.flashMode == .automatic)
            }

            Button {
                controls.setFlashMode(.on)
            } label: {
                settingLabel("On", isSelected: controls.settings.flashMode == .on)
            }
        }
    }

    private func settingLabel(_ title: String, isSelected: Bool) -> some View {
        Group {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
