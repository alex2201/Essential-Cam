//
//  CameraView.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import SwiftUI

struct CameraView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = CameraViewModel()
    @State private var isSettingsPresented = false
    @State private var isGalleryPresented = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: .zero) {
#if targetEnvironment(simulator)
                CameraCaptureView(
                    viewModel: viewModel,
                    showSettings: { isSettingsPresented = true },
                    showGallery: { isGalleryPresented = true }
                )
#else
                switch viewModel.cameraStatus {
                case .running:
                    CameraCaptureView(
                        viewModel: viewModel,
                        showSettings: { isSettingsPresented = true },
                        showGallery: { isGalleryPresented = true }
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
        .fullScreenCover(isPresented: $isSettingsPresented) {
            CameraSettingsView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $isGalleryPresented) {
            PhotoGalleryView()
        }
        .task {
#if !targetEnvironment(simulator)
            await viewModel.start()
#endif
            await viewModel.refreshRecentPhotoThumbnails()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await viewModel.refreshRecentPhotoThumbnails()
            }
        }
    }
}
