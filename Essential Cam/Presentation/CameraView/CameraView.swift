//
//  CameraView.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFAudio
import SwiftUI
import UIKit

struct CameraView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(CameraPresetStore.self) private var presetStore
    @Environment(QuickSettingsStore.self) private var quickSettingsStore
    @State private var viewModel = CameraViewModel()
    @State private var orientationController = CameraOrientationController()
    @State private var isSettingsPresented = false
    @State private var isGalleryPresented = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: .zero) {
#if targetEnvironment(simulator)
                CameraCaptureView(
                    viewModel: viewModel,
                    iconOrientation: orientationController.orientation,
                    showSettings: { isSettingsPresented = true },
                    showGallery: { isGalleryPresented = true }
                )
#else
                switch viewModel.cameraStatus {
                case .running:
                    CameraCaptureView(
                        viewModel: viewModel,
                        iconOrientation: orientationController.orientation,
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
#else
            viewModel.cameraStatus = .running
            await viewModel.controls.synchronizeWithCamera()
#endif
            await viewModel.refreshRecentPhotoThumbnails()
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task {
                await viewModel.handleScenePhase(
                    isActive: newPhase == .active,
                    isBackground: newPhase == .background
                )
                if newPhase == .active, !isGalleryPresented {
                    await viewModel.controls.refreshVideoMicrophones()
                }
            }
        }
        .onChange(of: isGalleryPresented) { _, presented in
            if !presented { Task { await viewModel.controls.refreshVideoMicrophones() } }
        }
        .task(id: viewModel.selectedCaptureMode) {
#if !targetEnvironment(simulator)
            await viewModel.checkVideoPermissions()
#endif
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            let rawReason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
            guard !isGalleryPresented,
                  let rawReason, let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason),
                  reason == .newDeviceAvailable || reason == .oldDeviceUnavailable
                    || (reason == .routeConfigurationChange && viewModel.isRecordingVideo) else { return }
            Task {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                await viewModel.controls.refreshVideoMicrophones()
            }
        }
        .onChange(of: viewModel.controls.settings, initial: true) { _, settings in
            quickSettingsStore.captureMode = settings.captureMode
            presetStore.activate(settings.captureMode)
            presetStore.updateUnselectedSettings(settings)
        }
        .alert(item: $viewModel.activeAlert, content: alert(for:))
        .task(id: scenePhase == .active && !isSettingsPresented && !isGalleryPresented) {
            guard scenePhase == .active, !isSettingsPresented, !isGalleryPresented else { return }
            await orientationController.observe()
        }
    }

    @ViewBuilder
    private func cameraWithStatusOverlay(
        title: String,
        message: String,
        showsProgress: Bool
    ) -> some View {
        CameraCaptureView(
            viewModel: viewModel,
            iconOrientation: orientationController.orientation,
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
        case let .videoPermissionRequired(permission):
            Alert(
                title: Text(permission.alertTitle),
                message: Text(permission.alertMessage),
                primaryButton: .default(Text("Open Settings"), action: openSettings),
                secondaryButton: .cancel()
            )
        case .videoRecordingFailed:
            Alert(
                title: Text("Video Not Recorded"),
                message: Text("The camera couldn't complete the recording. Please try again."),
                dismissButton: .default(Text("OK"))
            )
        case .videoSaveFailed:
            Alert(
                title: Text("Video Not Saved"),
                message: Text("Your recording is retained on this device. Check Photos access and available storage, then retry. An interrupted file may need to be discarded."),
                primaryButton: .default(Text("Retry"), action: viewModel.retryPendingVideoSave),
                secondaryButton: .destructive(Text("Discard"), action: viewModel.discardPendingVideo)
            )
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
                secondaryButton: .destructive(Text("Discard"), action: viewModel.discardPendingPhoto)
            )
        case .pendingPhotoStorageFailed:
            Alert(
                title: Text("Photo Storage Error"),
                message: Text("The captured photo couldn't be secured on this device. Retry or discard it before taking another photo."),
                primaryButton: .default(Text("Retry"), action: viewModel.retryPendingPhotoSave),
                secondaryButton: .destructive(Text("Discard"), action: viewModel.discardPendingPhoto)
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

private extension VideoPermission {
    var alertTitle: String {
        switch self {
        case .camera: "Camera Access Required"
        case .microphone: "Microphone Access Required"
        case .photoLibrary: "Photos Access Required"
        }
    }

    var alertMessage: String {
        switch self {
        case .camera:
            "Allow camera access in Settings to record video. You can also return to Photo mode."
        case .microphone:
            "Allow microphone access in Settings to record video with audio. You can still take photos."
        case .photoLibrary:
            "Allow Essential Cam to add photos and videos in Settings to save your recordings."
        }
    }
}
