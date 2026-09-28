//
//  CameraView.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import SwiftUI
import UIKit

struct CameraView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var viewModel = CameraViewModel()
    @State private var isSettingsPresented = false
    @State private var isGalleryPresented = false

    var body: some View {
        ZStack {
            Color.cyan

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
                case let .interrupted(reason):
                    cameraWithStatusOverlay(
                        title: "Camera Paused",
                        message: interruptionMessage(reason),
                        showsProgress: false
                    )
                case .recovering:
                    cameraWithStatusOverlay(
                        title: "Restoring Camera",
                        message: "Please wait a moment.",
                        showsProgress: true
                    )
                case .failed:
                    ContentUnavailableView {
                        Label("Camera Unavailable", systemImage: "camera.fill.badge.exclamationmark")
                    } description: {
                        Text("Essential Cam couldn't restore the camera.")
                    } actions: {
                        Button("Try Again", action: viewModel.retryCamera)
                    }
                case .unauthorized:
                    ContentUnavailableView {
                        Label("Camera Access Required", systemImage: "camera.fill")
                    } description: {
                        Text("Allow camera access in Settings to take photos.")
                    } actions: {
                        Button("Open Settings", action: openSettings)
                    }
                case .idle, .requestingPermission, .starting:
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
            Task {
                await viewModel.handleScenePhase(
                    isActive: newPhase == .active,
                    isBackground: newPhase == .background
                )
            }
        }
        .alert(item: $viewModel.activeAlert, content: alert(for:))
    }

    @ViewBuilder
    private func cameraWithStatusOverlay(
        title: String,
        message: String,
        showsProgress: Bool
    ) -> some View {
        CameraCaptureView(
            viewModel: viewModel,
            showSettings: { isSettingsPresented = true },
            showGallery: { isGalleryPresented = true }
        )
        .overlay {
            VStack(spacing: 12) {
                if showsProgress { ProgressView() }
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .padding()
        }
    }

    private func interruptionMessage(_ interruption: CameraInterruption) -> String {
        switch interruption {
        case .appInactive:
            "The camera will resume when Essential Cam is active."
        case .audioOrVideoInUse:
            "Another app or a call is temporarily using the camera."
        case .multipleForegroundApps:
            "The camera isn't available while multiple apps are active."
        case .systemPressure:
            "The device needs a moment before the camera can continue."
        case .unknown:
            "The camera was temporarily interrupted."
        }
    }

    private func alert(for alert: CameraAlert) -> Alert {
        switch alert {
        case .captureFailed:
            Alert(
                title: Text("Photo Not Captured"),
                message: Text("The camera couldn't complete the photo. Please try again."),
                dismissButton: .default(Text("OK"))
            )
        case .photoSaveFailed:
            Alert(
                title: Text("Photo Not Saved"),
                message: Text("The photo is still available temporarily. You can retry saving it."),
                primaryButton: .default(Text("Retry"), action: viewModel.retryPendingPhotoSave),
                secondaryButton: .destructive(Text("Discard"), action: viewModel.discardPendingPhoto)
            )
        case .photoLibraryUnauthorized:
            Alert(
                title: Text("Photos Access Required"),
                message: Text("Allow Essential Cam to add photos in Settings, then retry."),
                primaryButton: .default(Text("Open Settings"), action: openSettings),
                secondaryButton: .cancel(Text("Keep Photo"))
            )
        case .cameraSwitchFailed:
            Alert(
                title: Text("Couldn't Change Camera"),
                message: Text("The previous camera remains selected."),
                dismissButton: .default(Text("OK"))
            )
        case .cameraRecoveryFailed:
            Alert(
                title: Text("Camera Unavailable"),
                message: Text("Essential Cam couldn't restore the camera."),
                primaryButton: .default(Text("Try Again"), action: viewModel.retryCamera),
                secondaryButton: .cancel()
            )
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
