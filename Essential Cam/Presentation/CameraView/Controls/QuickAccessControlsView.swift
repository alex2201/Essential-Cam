//
//  QuickAccessControlsView.swift
//  Essential Cam
//

import SwiftUI

struct QuickAccessControlsView: View {
    let viewModel: CameraViewModel

    var body: some View {
        VStack(spacing: 8) {
            Menu {
                ForEach(CameraAspectRatio.allCases, id: \.self) { ratio in
                    Button {
                        viewModel.cameraSettings.aspectRatio = ratio
                    } label: {
                        if ratio == viewModel.cameraSettings.aspectRatio {
                            Label(ratio.displayName, systemImage: "checkmark")
                        } else {
                            Text(ratio.displayName)
                        }
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Text("FMT")
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.cameraSettings.aspectRatio.displayName)
                        .font(.system(size: 10))
                }
            }

            separator

            VStack(spacing: 4) {
                Text("EV")
                    .font(.system(size: 12, weight: .semibold))
                Text("2.35")
                    .font(.system(size: 10))
            }

            separator

            VStack(spacing: 4) {
                Text("AF")
                    .font(.system(size: 12, weight: .semibold))
                Text("200.0")
                    .font(.system(size: 10))
            }

            separator

            Menu {
                whiteBalanceMenu
                flashMenu
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More camera settings")
        }
        .font(.caption)
        .foregroundStyle(Color.white)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
        }
        .frame(maxWidth: 45)
        .padding(.horizontal, 8)
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
                viewModel.cameraSettings.whiteBalance = .auto
            } label: {
                settingLabel("Auto", isSelected: viewModel.cameraSettings.whiteBalance == .auto)
            }

            Button {
                viewModel.cameraSettings.whiteBalance = .continuousAuto
            } label: {
                settingLabel(
                    "Continuous auto",
                    isSelected: viewModel.cameraSettings.whiteBalance == .continuousAuto
                )
            }

            Button {
                viewModel.cameraSettings.whiteBalance = .locked
            } label: {
                settingLabel("Locked", isSelected: viewModel.cameraSettings.whiteBalance == .locked)
            }
        }
    }

    private var flashMenu: some View {
        Menu("Flash") {
            Button {
                viewModel.cameraSettings.flashMode = .off
            } label: {
                settingLabel("Off", isSelected: viewModel.cameraSettings.flashMode == .off)
            }

            Button {
                viewModel.cameraSettings.flashMode = .automatic
            } label: {
                settingLabel("Auto", isSelected: viewModel.cameraSettings.flashMode == .automatic)
            }

            Button {
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
