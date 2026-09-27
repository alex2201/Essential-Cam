//
//  CameraCaptureView.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

import SwiftUI

struct CameraCaptureView: View {
    let viewModel: CameraViewModel
    let showSettings: () -> Void

    @State private var zoomFactorAtGestureStart: Double?

    var body: some View {
        GeometryReader { geometry in
            let previewContainerHeight = min(
                geometry.size.width * 16 / 9,
                geometry.size.height
            )
            let previewWidthToHeight = viewModel.controls.settings.aspectRatio.previewWidthToHeight
            ZStack {
                VStack(spacing: .zero) {
                    ZStack {
                        Color.clear

                        CameraPreview(session: viewModel.captureSession)
                            .aspectRatio(previewWidthToHeight, contentMode: .fit)
                            .clipped()
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .center
                            )
                            .contentShape(Rectangle())
                            .gesture(zoomGesture)
                    }
                    .frame(width: geometry.size.width, height: previewContainerHeight)
                }

            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .trailing) {
                CameraControlsOverlayView(viewModel: viewModel)
            }
            .overlay(alignment: .topTrailing) {
                CameraFlashButton(controls: viewModel.controls)
                    .padding(8)
            }
            .overlay(alignment: .topLeading) {
                CameraSettingsButton(action: showSettings)
                    .padding(8)
            }
            .overlay(alignment: .bottom) {
                CaptureControlsView(
                    captureAction: viewModel.captureAction,
                    isCaptureDisabled: viewModel.isPerformingCaptureOperation
                )
                .padding(.bottom, 42)
            }
        }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let startingZoomFactor = zoomFactorAtGestureStart
                    ?? viewModel.controls.settings.zoomFactor
                zoomFactorAtGestureStart = startingZoomFactor
                viewModel.controls.setZoomFactor(
                    startingZoomFactor * Double(value.magnification)
                )
            }
            .onEnded { _ in
                zoomFactorAtGestureStart = nil
            }
    }

}
