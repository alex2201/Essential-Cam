//
//  LensSelectionView.swift
//  Essential Cam
//
//  Created by Codex on 25/09/26.
//

import SwiftUI

struct LensSelectorButton: View {
    let camera: Camera?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(
                    systemName: camera?.isVirtual == true
                        ? "camera.viewfinder.badge.automatic"
                        : "camera.fill"
                )
                    .font(.system(size: 16, weight: .semibold))

                Text(camera?.compactDisplayName ?? "1×")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose camera lens")
        .accessibilityValue(camera?.zoomFactorAccessibilityName ?? "1 times")
    }
}

struct CameraSelectionControlsView: View {
    let camera: Camera?
    let canSwitchPosition: Bool
    let isSwitchingPosition: Bool
    let showLensSelector: () -> Void
    let toggleCameraPosition: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LensSelectorButton(
                camera: camera,
                action: showLensSelector
            )

            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(height: 1)
                .padding(.horizontal, 8)

            Button(action: toggleCameraPosition) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSwitchPosition || isSwitchingPosition)
            .opacity(canSwitchPosition ? 1 : 0.45)
            .accessibilityLabel("Switch between front and back camera")
            .accessibilityValue(camera?.position.accessibilityName ?? "Unavailable")
        }
        .frame(width: 45)
        .cameraControlBackground(cornerRadius: 12)
        .padding(.horizontal, 8)
    }
}

struct LensSelectionView: View {
    let physicalCameras: [Camera]
    let virtualCamera: Camera?
    let selectedCamera: Camera?
    let selectCamera: (Camera) -> Void
    let dismiss: () -> Void

    private var sortedCameras: [Camera] {
        physicalCameras.sorted {
            ($0.displayZoomFactor ?? .greatestFiniteMagnitude)
                < ($1.displayZoomFactor ?? .greatestFiniteMagnitude)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                if let virtualCamera {
                    selectCamera(virtualCamera)
                }
            } label: {
                Image(systemName: "camera.viewfinder.badge.automatic")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selectedCamera?.isVirtual == true ? Color.yellow : Color.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(virtualCamera == nil)
            .background {
                Circle()
                    .fill(.black.opacity(0.55))
            }
            .accessibilityLabel("Virtual camera devices")
            .accessibilityValue(selectedCamera?.isVirtual == true ? "Selected" : "Not selected")
            .accessibilityAddTraits(selectedCamera?.isVirtual == true ? .isSelected : [])

            VStack(spacing: 0) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 45, height: 28)
                    .padding(.top, 8)
                    .accessibilityHidden(true)

                if sortedCameras.isEmpty {
                    Text("—")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 45, height: 44)
                        .accessibilityLabel("No virtual camera devices available")
                } else {
                    ForEach(Array(sortedCameras.enumerated()), id: \.element.id) { index, camera in
                        if index > 0 {
                            separator
                        }

                        Button {
                            selectCamera(camera)
                        } label: {
                            Text(camera.compactDisplayName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    camera.id == selectedCamera?.id ? Color.yellow : Color.white
                                )
                                .frame(width: 45, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(camera.accessibilityName)
                        .accessibilityAddTraits(
                            camera.id == selectedCamera?.id ? .isSelected : []
                        )
                    }
                }
            }
            .cameraControlBackground(cornerRadius: 12)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background {
                        Circle()
                            .fill(.black.opacity(0.55))
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close lens selection")
        }
        .padding(.horizontal, 8)
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.35))
            .frame(width: 29, height: 1)
    }
}

private extension Camera {
    var isVirtual: Bool {
        if case .virtual = deviceKind {
            return true
        }
        return false
    }

    var compactDisplayName: String {
        switch deviceKind {
        case .physical:
            zoomFactorDisplayName
        case .virtual:
            "AUTO"
        }
    }

    var accessibilityName: String {
        switch deviceKind {
        case .physical:
            zoomFactorAccessibilityName
        case .virtual:
            name
        }
    }

    var zoomFactorDisplayName: String {
        guard let displayZoomFactor else {
            return lens.fallbackDisplayName
        }

        return displayZoomFactor.formatted(
            .number.precision(.fractionLength(displayZoomFactor == displayZoomFactor.rounded() ? 0 : 1))
        ) + "×"
    }

    var zoomFactorAccessibilityName: String {
        zoomFactorDisplayName.replacingOccurrences(of: "×", with: " times")
    }
}

private extension Camera.Lens {
    var fallbackDisplayName: String {
        switch self {
        case .ultraWideAngle:
            "0.5×"
        case .wideAngle:
            "1×"
        case .telephoto:
            "3×"
        case .unknown:
            "—"
        }
    }
}

private extension Camera.Position {
    var accessibilityName: String {
        switch self {
        case .front:
            "Front camera"
        case .back:
            "Back camera"
        }
    }
}

private extension View {
    @ViewBuilder
    func cameraControlBackground(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(
                .regular
                    .tint(.black.opacity(0.35))
                    .interactive(),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.55))
            }
        }
    }
}
