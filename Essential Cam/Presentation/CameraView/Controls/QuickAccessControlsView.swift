//
//  QuickAccessControlsView.swift
//  Essential Cam
//

import SwiftUI

struct QuickAccessControlsView: View {
    let viewModel: CameraViewModel
    let isExposureDialPresented: Bool
    let toggleExposureDial: () -> Void
    let dismissActiveDial: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                controls
                    .glassEffect(
                        .regular,
                        in: .rect(cornerRadius: 12)
                    )
            } else {
                controls
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.4))
                    }
            }
        }
        .frame(width: 45)
        .padding(.horizontal, 8)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Menu {
                ForEach(CameraAspectRatio.allCases, id: \.self) { ratio in
                    Button {
                        dismissActiveDial()
                        viewModel.cameraSettings.aspectRatio = ratio
                    } label: {
                        settingLabel(
                            ratio.displayName,
                            isSelected: ratio == viewModel.cameraSettings.aspectRatio
                        )
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Text("FMT")
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.cameraSettings.aspectRatio.displayName)
                        .font(.system(size: 10))
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }

            separator

            Button(action: toggleExposureDial) {
                VStack(spacing: 4) {
                    Text("EV")
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.cameraSettings.exposure.displayName)
                        .font(.system(size: 10))
                }
                .foregroundStyle(
                    isExposureDialPresented ? Color.yellow : Color.gray
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }

            separator

            Menu {
                Button {
                    dismissActiveDial()
                    viewModel.cameraSettings.focus = .auto
                } label: {
                    settingLabel(
                        "Auto",
                        isSelected: viewModel.cameraSettings.focus == .auto
                    )
                }

                Button {
                    dismissActiveDial()
                    viewModel.cameraSettings.focus = .continuousAuto
                } label: {
                    settingLabel(
                        "Continuous auto",
                        isSelected: viewModel.cameraSettings.focus == .continuousAuto
                    )
                }

                Button {
                    dismissActiveDial()
                    viewModel.cameraSettings.focus = .locked
                } label: {
                    settingLabel(
                        "Locked",
                        isSelected: viewModel.cameraSettings.focus == .locked
                    )
                }

                Menu("Manual") {
                    ForEach(FocusSetting.manualLensPositionOptions, id: \.self) { lensPosition in
                        Button {
                            dismissActiveDial()
                            viewModel.cameraSettings.focus = .manual(
                                lensPosition: lensPosition
                            )
                        } label: {
                            settingLabel(
                                lensPosition.lensPositionDisplayName,
                                isSelected: viewModel.cameraSettings.focus
                                    .hasLensPosition(lensPosition)
                            )
                        }
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Text("AF")
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.cameraSettings.focus.displayName)
                        .font(.system(size: 10))
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }

            separator

            Menu {
                whiteBalanceMenu
                flashMenu
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More camera settings")
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .font(.caption)
        .foregroundStyle(Color.gray)
        .padding(.vertical, 12)
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.7))
            .frame(height: 1)
            .padding(.horizontal, 8)
    }

    private var whiteBalanceMenu: some View {
        Menu("White balance") {
            Button {
                dismissActiveDial()
                viewModel.cameraSettings.whiteBalance = .auto
            } label: {
                settingLabel("Auto", isSelected: viewModel.cameraSettings.whiteBalance == .auto)
            }

            Button {
                dismissActiveDial()
                viewModel.cameraSettings.whiteBalance = .continuousAuto
            } label: {
                settingLabel(
                    "Continuous auto",
                    isSelected: viewModel.cameraSettings.whiteBalance == .continuousAuto
                )
            }

            Button {
                dismissActiveDial()
                viewModel.cameraSettings.whiteBalance = .locked
            } label: {
                settingLabel("Locked", isSelected: viewModel.cameraSettings.whiteBalance == .locked)
            }
        }
    }

    private var flashMenu: some View {
        Menu("Flash") {
            Button {
                dismissActiveDial()
                viewModel.cameraSettings.flashMode = .off
            } label: {
                settingLabel("Off", isSelected: viewModel.cameraSettings.flashMode == .off)
            }

            Button {
                dismissActiveDial()
                viewModel.cameraSettings.flashMode = .automatic
            } label: {
                settingLabel("Auto", isSelected: viewModel.cameraSettings.flashMode == .automatic)
            }

            Button {
                dismissActiveDial()
                viewModel.cameraSettings.flashMode = .on
            } label: {
                settingLabel("On", isSelected: viewModel.cameraSettings.flashMode == .on)
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
