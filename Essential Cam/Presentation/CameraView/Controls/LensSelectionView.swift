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
        .accessibilityValue(camera?.accessibilityName ?? "Unavailable")
    }
}

struct ZoomSelectorButton: View {
    let zoomFactor: Double
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))

                Text(zoomFactor.zoomFactorDisplayName)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel("Choose zoom level")
        .accessibilityValue(zoomFactor.zoomFactorAccessibilityName)
    }
}

struct CameraSelectionControlsView: View {
    let camera: Camera?
    let zoomFactor: Double
    let canSelectZoom: Bool
    let canSwitchPosition: Bool
    let isSwitchingPosition: Bool
    let showLensSelector: () -> Void
    let showZoomSelector: () -> Void
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

            ZoomSelectorButton(
                zoomFactor: zoomFactor,
                isEnabled: canSelectZoom,
                action: showZoomSelector
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

struct ZoomSelectionView: View {
    let zoomFactors: [Double]
    let selectedZoomFactor: Double
    let selectZoomFactor: (Double) -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 45, height: 36)
                    .padding(.top, 4)
                    .accessibilityHidden(true)

                ForEach(Array(zoomFactors.enumerated()), id: \.offset) { index, zoomFactor in
                    if index > 0 {
                        Rectangle()
                            .fill(.white.opacity(0.35))
                            .frame(width: 29, height: 1)
                    }

                    Button {
                        selectZoomFactor(zoomFactor)
                    } label: {
                        Text(zoomFactor.zoomFactorDisplayName)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                abs(zoomFactor - selectedZoomFactor) < 0.01
                                    ? Color.yellow
                                    : Color.white
                            )
                            .frame(width: 45, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(zoomFactor.zoomFactorAccessibilityName)
                    .accessibilityAddTraits(
                        abs(zoomFactor - selectedZoomFactor) < 0.01 ? .isSelected : []
                    )
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
            .accessibilityLabel("Close zoom selection")
        }
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
                                .font(.system(size: 10))
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
            focalLengthDisplayName
        case .virtual:
            "AUTO"
        }
    }

    var accessibilityName: String {
        switch deviceKind {
        case .physical:
            [lens.accessibilityName, focalLengthAccessibilityName, position.accessibilityName]
                .compactMap { $0 }
                .joined(separator: ", ")
        case .virtual:
            "Automatic multi-camera, \(position.accessibilityName)"
        }
    }

    var focalLengthDisplayName: String {
        guard let nominalFocalLengthIn35mmFilm else {
            return lens.fallbackDisplayName
        }

        return nominalFocalLengthIn35mmFilm.formatted(
            .number.precision(.fractionLength(0))
        ) + " mm"
    }

    var focalLengthAccessibilityName: String? {
        guard let nominalFocalLengthIn35mmFilm else { return nil }
        return nominalFocalLengthIn35mmFilm.formatted(
            .number.precision(.fractionLength(0))
        ) + " millimeters"
    }
}

private extension Camera.Lens {
    var fallbackDisplayName: String {
        switch self {
        case .ultraWideAngle:
            "UW"
        case .wideAngle:
            "W"
        case .telephoto:
            "T"
        case .unknown:
            "—"
        }
    }

    var accessibilityName: String? {
        switch self {
        case .ultraWideAngle:
            "Ultra-wide-angle camera"
        case .wideAngle:
            "Wide-angle camera"
        case .telephoto:
            "Telephoto camera"
        case .unknown:
            nil
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

private extension Double {
    var zoomFactorDisplayName: String {
        formatted(.number.precision(.fractionLength(0...1))) + "×"
    }

    var zoomFactorAccessibilityName: String {
        formatted(.number.precision(.fractionLength(0...1))) + " times"
    }
}

extension View {
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
