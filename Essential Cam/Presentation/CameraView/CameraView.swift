//
//  CameraView.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import SwiftUI

struct CameraView: View {
    @State private var viewModel = CameraViewModel()
    @State private var isSettingsPresented = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: .zero) {
#if targetEnvironment(simulator)
                CameraCaptureView(
                    viewModel: viewModel,
                    showSettings: { isSettingsPresented = true }
                )
#else
                switch viewModel.cameraStatus {
                case .running:
                    CameraCaptureView(
                        viewModel: viewModel,
                        showSettings: { isSettingsPresented = true }
                    )
                case .failed, .interrupted:
                    Text("Something went wrong")
                case .unauthorized:
                    Text("Camera access is denied. Open Settings and allow access")
                case .unknown:
                    ProgressView()
                }
#endif
            }
        }
        .sheet(isPresented: $viewModel.isPhotoPreviewPresented) {
            if let previewImage = viewModel.capturedPhotoPreview {
                CapturedPhotoPreview(previewImage: previewImage)
                    .onDisappear {
                        viewModel.capturedPhotoPreview = nil
                    }
            }
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            CameraSettingsView(viewModel: viewModel)
        }
        .task {
#if !targetEnvironment(simulator)
            await viewModel.start()
#endif
        }
    }
}

extension CameraView {
    struct CapturedPhotoPreview: View {
        let previewImage: CGImage

        var body: some View {
            Image(decorative: previewImage, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}
