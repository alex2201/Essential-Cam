//
//  QuickAccessControlsView.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

import SwiftUI

struct QuickAccessControlsView: View {
    @Environment(QuickSettingsStore.self) private var store
    let controls: CameraControlsController
    let showAspectRatioSelector: () -> Void
    let showPhotoTimerSelector: () -> Void
    let showPhotoResolutionSelector: () -> Void
    let showExposureEditor: () -> Void
    let showFocusEditor: () -> Void
    let showWhiteBalanceEditor: () -> Void
    let showVideoSetting: (QuickSettingControl) -> Void

    var body: some View {
        controlsContent
            .cameraControlBackground(cornerRadius: 12)
            .frame(width: 45)
            .padding(.horizontal, 8)
    }

    private var controlsContent: some View {
        VStack(spacing: 8) {
            ForEach(Array(visibleControls.enumerated()), id: \.element) { index, control in
                if index > 0 { separator }
                controlButton(control)
            }
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(.vertical, 12)
    }

    private var visibleControls: [QuickSettingControl] {
        store.included.filter { control in
            QuickSettingControl.controls(for: controls.captureMode).contains(control)
                && (control != .videoTorch || controls.videoCapabilities.supportsTorch)
        }
    }

    @ViewBuilder
    private func controlButton(_ control: QuickSettingControl) -> some View {
        switch control {
        case .aspectRatio:
            Button(action: showAspectRatioSelector) {
                VStack(spacing: 4) {
                    Image(systemName: "aspectratio")
                        .font(.system(size: 16, weight: .semibold))
                    Text(controls.settings.aspectRatio.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .cameraControlContentRotation()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose aspect ratio")
            .accessibilityValue(controls.settings.aspectRatio.accessibilityName)
        case .photoTimer:
            quickSettingButton(
                icon: "timer",
                value: controls.settings.photoTimer.displayName,
                accessibilityLabel: "Choose photo timer",
                action: showPhotoTimerSelector
            )
        case .photoResolution:
            quickSettingButton(
                icon: "photo",
                value: controls.settings.photoResolution?.megapixelDisplayName ?? "Auto",
                accessibilityLabel: "Choose photo resolution",
                action: showPhotoResolutionSelector
            )
        case .exposure:
            Button(action: showExposureEditor) {
                VStack(spacing: 4) {
                    Text("EXP")
                        .font(.system(size: 12, weight: .semibold))
                    Text(controls.settings.exposure.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .cameraControlContentRotation()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("camera.quick.exposure")
        case .focus:
            Button(action: showFocusEditor) {
                VStack(spacing: 4) {
                    Text("AF")
                        .font(.system(size: 12, weight: .semibold))
                    Text(controls.settings.focus.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .cameraControlContentRotation()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("camera.quick.focus")
        case .whiteBalance:
            Button(action: showWhiteBalanceEditor) {
                VStack(spacing: 4) {
                    Text("WB")
                        .font(.system(size: 12, weight: .semibold))
                    Text(controls.settings.whiteBalance.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .cameraControlContentRotation()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("camera.quick.whiteBalance")
        case .videoResolution:
            quickSettingButton(icon: "video", value: controls.settings.video.resolution.displayName,
                accessibilityLabel: "Choose video resolution", action: { showVideoSetting(control) })
        case .videoFrameRate:
            quickSettingButton(icon: "speedometer", value: String(controls.settings.video.frameRate.rawValue),
                accessibilityLabel: "Choose frame rate", action: { showVideoSetting(control) })
        case .videoCodec:
            quickSettingButton(icon: "film", value: controls.settings.video.codec.shortName,
                accessibilityLabel: "Choose video codec", action: { showVideoSetting(control) })
        case .videoStabilization:
            quickSettingButton(icon: "hand.raised", value: controls.settings.video.stabilization.displayName,
                accessibilityLabel: "Choose stabilization", action: { showVideoSetting(control) })
        case .videoMicrophone:
            quickSettingButton(icon: "mic", value: controls.settings.video.microphone.displayName,
                accessibilityLabel: "Choose microphone", action: { showVideoSetting(control) })
        case .videoTorch:
            quickSettingButton(icon: "flashlight.on.fill", value: controls.settings.video.torch ? "On" : "Off",
                accessibilityLabel: "Choose continuous light", action: { showVideoSetting(control) })

        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.35))
            .frame(height: 1)
            .padding(.horizontal, 8)
    }

    private func quickSettingButton(
        icon: String,
        value: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(value)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .cameraControlContentRotation()
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(value)
    }
}

struct QuickSettingSelectionView<Value: Hashable>: View {
    let title: String
    let icon: String
    let values: [Value]
    let selectedValue: Value?
    let label: (Value) -> String
    let select: (Value) -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .cameraIconRotation()
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 40)
                    .accessibilityHidden(true)

                ForEach(values, id: \.self) { value in
                    Rectangle()
                        .fill(.white.opacity(0.35))
                        .frame(width: 40, height: 1)
                    Button {
                        select(value)
                    } label: {
                        Text(label(value))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(value == selectedValue ? Color.yellow : Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .frame(width: 60, height: 44)
                            .cameraControlContentRotation()
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(value == selectedValue ? .isSelected : [])
                }
            }
            .cameraControlBackground(cornerRadius: 12)
            .accessibilityLabel(title)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .cameraIconRotation()
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .cameraControlCircleBackground()
            .accessibilityLabel("Close \(title) selection")
        }
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
                    .cameraIconRotation()
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .frame(width: 45, height: 44)
                            .cameraControlContentRotation()
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
                    .cameraIconRotation()
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
