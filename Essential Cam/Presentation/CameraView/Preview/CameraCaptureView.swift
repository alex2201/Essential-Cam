//
//  CameraCaptureView.swift
//  Essential Cam
//

import SwiftUI

struct CameraCaptureView: View {
    let viewModel: CameraViewModel

    @State private var isExposureDialPresented = false

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
                    QuickAccessControlsView(
                        viewModel: viewModel,
                        isExposureDialPresented: isExposureDialPresented,
                        toggleExposureDial: toggleExposureDial,
                        dismissActiveDial: dismissExposureDial
                    )
                }
                .overlay(alignment: .bottom) {
                    if isExposureDialPresented {
                        CameraValueDial(
                            value: exposureBias,
                            range: -2...2,
                            step: 0.1,
                            title: "EV"
                        )
                        .frame(maxWidth: 280)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
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

    private var exposureBias: Binding<Double> {
        Binding(
            get: {
                Double(viewModel.cameraSettings.exposure.exposureBias ?? 0)
            },
            set: { newValue in
                viewModel.cameraSettings.exposure = viewModel
                    .cameraSettings
                    .exposure
                    .settingExposureBias(Float(newValue))
            }
        )
    }

    private func toggleExposureDial() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isExposureDialPresented.toggle()
        }
    }

    private func dismissExposureDial() {
        guard isExposureDialPresented else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            isExposureDialPresented = false
        }
    }
}
