//
//  CameraCaptureView.swift
//  Essential Cam
//

import SwiftUI

struct CameraCaptureView: View {
    let viewModel: CameraViewModel

    var body: some View {
        GeometryReader { geometry in
            let previewContainerHeight = min(
                geometry.size.width * 16 / 9,
                geometry.size.height
            )

            VStack(spacing: .zero) {
                ZStack {
                    Color.clear

                    CameraPreview(session: viewModel.captureSession)
                        .aspectRatio(
                            viewModel.cameraSettings.aspectRatio.previewWidthToHeight,
                            contentMode: .fit
                        )
                        .clipped()
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .center
                        )
                }
                .frame(width: geometry.size.width, height: previewContainerHeight)
                .overlay(alignment: .trailing) {
                    QuickAccessControlsView(viewModel: viewModel)
                }

                CaptureControlsView(
                    captureAction: viewModel.captureAction,
                    isCaptureDisabled: viewModel.isPerformingCaptureOperation
                )
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height - previewContainerHeight
                )
            }
        }
    }
}
