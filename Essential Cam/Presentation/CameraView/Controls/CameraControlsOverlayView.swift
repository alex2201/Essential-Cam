//
//  CameraControlsOverlayView.swift
//  Essential Cam
//
//  Created by Codex on 27/09/26.
//

import SwiftUI

struct CameraControlsOverlayView: View {
    let viewModel: CameraViewModel

    @State private var presentedControl: PresentedCameraControl?

    var body: some View {
        ZStack(alignment: .trailing) {
            switch presentedControl {
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
            case nil:
                defaultControls
                    .transition(controlTransition)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: presentedControl)
    }

    private var defaultControls: some View {
        VStack(spacing: 24) {
            QuickAccessControlsView(
                controls: viewModel.controls,
                showAspectRatioSelector: { present(.aspectRatio) },
                showExposureEditor: { present(.exposure) },
                showFocusEditor: { present(.focus) },
                showWhiteBalanceEditor: { present(.whiteBalance) }
            )

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

    private var controlTransition: AnyTransition {
        .move(edge: .trailing).combined(with: .opacity)
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
        withAnimation(.easeInOut(duration: 0.25)) {
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
        withAnimation(.easeInOut(duration: 0.25)) {
            presentedControl = nil
        }
    }
}

private enum PresentedCameraControl: Equatable {
    case aspectRatio
    case exposure
    case focus
    case whiteBalance
    case lens
    case zoom
}
