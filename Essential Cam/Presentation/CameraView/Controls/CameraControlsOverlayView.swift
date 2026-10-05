//
//  CameraControlsOverlayView.swift
//  Essential Cam
//
//  Created by Alexander López on 27/09/26.
//

import SwiftUI

struct CameraControlsOverlayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(QuickSettingsStore.self) private var quickSettingsStore
    let viewModel: CameraViewModel

    @State private var presentedControl: PresentedCameraControl?

    var body: some View {
        ZStack(alignment: .trailing) {
            if presentedControl != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissPresentedControl)
                    .accessibilityHidden(true)
            }

            switch presentedControl {
            case .photoTimer:
                QuickSettingSelectionView(
                    title: "Photo timer",
                    icon: "timer",
                    values: PhotoTimer.allCases,
                    selectedValue: viewModel.controls.settings.photoTimer,
                    label: { $0.displayName },
                    select: {
                        viewModel.controls.setPhotoTimer($0)
                        dismiss(.photoTimer)
                    },
                    dismiss: { dismiss(.photoTimer) }
                )
                .transition(controlTransition)
            case .photoResolution:
                QuickSettingSelectionView(
                    title: "Photo resolution",
                    icon: "photo",
                    values: viewModel.availablePhotoResolutions,
                    selectedValue: viewModel.controls.settings.photoResolution,
                    label: { $0.megapixelDisplayName },
                    select: {
                        viewModel.controls.setPhotoResolution($0)
                        dismiss(.photoResolution)
                    },
                    dismiss: { dismiss(.photoResolution) }
                )
                .transition(controlTransition)
            case .aspectRatio:
                AspectRatioSelectionView(
                    selectedAspectRatio: viewModel.controls.settings.aspectRatio,
                    selectAspectRatio: selectAspectRatio,
                    dismiss: { dismiss(.aspectRatio) }
                )
                .transition(controlTransition)
            case .exposure:
                ExposureControlEditor(
                    controls: viewModel.controls,
                    dismiss: { dismiss(.exposure) }
                )
                .transition(controlTransition)
            case .focus:
                FocusControlEditor(
                    controls: viewModel.controls,
                    dismiss: { dismiss(.focus) }
                )
                .transition(controlTransition)
            case .whiteBalance:
                WhiteBalanceControlEditor(
                    controls: viewModel.controls,
                    dismiss: { dismiss(.whiteBalance) }
                )
                .transition(controlTransition)
            case .lens:
                LensSelectionView(
                    physicalCameras: viewModel.availableCameras,
                    virtualCamera: viewModel.preferredVirtualCamera,
                    selectedCamera: viewModel.selectedCamera,
                    selectCamera: selectCamera,
                    dismiss: { dismiss(.lens) }
                )
                .transition(controlTransition)
            case .zoom:
                ZoomSelectionView(
                    zoomFactors: zoomSelectionFactors,
                    selectedZoomFactor: viewModel.controls.settings.zoomFactor,
                    selectZoomFactor: selectZoomFactor,
                    dismiss: { dismiss(.zoom) }
                )
                .transition(controlTransition)
            case let .video(control):
                VideoQuickSettingView(control: control, controls: viewModel.controls,
                    dismiss: dismissPresentedControl)
                    .transition(controlTransition)
            case nil:
                defaultControls
                    .transition(controlTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .animation(menuAnimation, value: presentedControl)
        .onChange(of: viewModel.selectedCaptureMode) { _, _ in dismissPresentedControl() }
    }

    private var defaultControls: some View {
        VStack(spacing: 24) {
            if !quickSettingsStore.included.isEmpty {
                QuickAccessControlsView(
                    controls: viewModel.controls,
                    showAspectRatioSelector: { present(.aspectRatio) },
                    showPhotoTimerSelector: { present(.photoTimer) },
                    showPhotoResolutionSelector: { present(.photoResolution) },
                    showExposureEditor: { present(.exposure) },
                    showFocusEditor: { present(.focus) },
                    showWhiteBalanceEditor: { present(.whiteBalance) },
                    showVideoSetting: { present(.video($0)) }
                )
            }

            CameraSelectionControlsView(
                camera: viewModel.selectedCamera,
                zoomFactor: viewModel.controls.settings.zoomFactor,
                canSelectZoom: !zoomSelectionFactors.isEmpty,
                canSwitchPosition: viewModel.canSwitchCameraPosition,
                isSwitchingPosition: viewModel.isSwitchingCameraPosition,
                showLensSelector: { present(.lens) },
                showZoomSelector: showZoomSelector,
                toggleCameraPosition: toggleCameraPosition
            )
        }
    }

    private var menuAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.32)
    }

    private var controlTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.96, anchor: .trailing).combined(with: .opacity)
    }

    private var zoomSelectionFactors: [Double] {
        guard let selectedCamera = viewModel.selectedCamera else { return [] }

        let baseZoomFactor: Double
        switch selectedCamera.deviceKind {
        case .physical:
            baseZoomFactor = selectedCamera.displayZoomFactor
                ?? viewModel.controls.zoomFactorRange.lowerBound
        case .virtual:
            baseZoomFactor = 1
        }
        let supportedRange = viewModel.controls.zoomFactorRange

        return [1.0, 2.0, 4.0]
            .map { baseZoomFactor * $0 }
            .filter { supportedRange.contains($0) }
    }

    private func present(_ control: PresentedCameraControl) {
        withAnimation(menuAnimation) {
            presentedControl = control
        }
    }

    private func dismiss(_ control: PresentedCameraControl) {
        guard presentedControl == control else { return }
        dismissPresentedControl()
    }

    private func showZoomSelector() {
        guard !zoomSelectionFactors.isEmpty else { return }
        present(.zoom)
    }

    private func selectAspectRatio(_ aspectRatio: CameraAspectRatio) {
        viewModel.controls.setAspectRatio(aspectRatio)
        dismiss(.aspectRatio)
    }

    private func selectZoomFactor(_ zoomFactor: Double) {
        viewModel.controls.setZoomFactor(zoomFactor)
        dismiss(.zoom)
    }

    private func selectCamera(_ camera: Camera) {
        dismissPresentedControl()
        viewModel.selectCamera(camera)
    }

    private func toggleCameraPosition() {
        dismissPresentedControl()
        viewModel.toggleCameraPosition()
    }

    private func dismissPresentedControl() {
        guard presentedControl != nil else { return }
        withAnimation(menuAnimation) {
            presentedControl = nil
        }
    }
}

private enum PresentedCameraControl: Equatable {
    case video(QuickSettingControl)
    case photoTimer
    case photoResolution
    case aspectRatio
    case exposure
    case focus
    case whiteBalance
    case lens
    case zoom
}
