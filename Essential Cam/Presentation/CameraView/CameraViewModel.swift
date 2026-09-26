//
//  CameraViewModel.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

@preconcurrency import AVFoundation
import Foundation

@MainActor
@Observable
final class CameraViewModel {
    // MARK: - View State

    var cameraStatus = CameraStatus.unknown
    var isPerformingCaptureOperation = false
    var capturedPhotoPreview: CGImage?
    var isPhotoPreviewPresented = false
    private(set) var captureOrientation = CaptureOrientation.portrait
    private(set) var availableCameras: [Camera] = []

    // MARK: - Camera Controls

    let controls: CameraControlsController

    // MARK: - Preview

    var captureSession: AVCaptureSession {
        cameraSession.captureSession
    }

    // MARK: - Dependencies

    private let cameraSession: CameraSession

    // MARK: - Initialization

    init(cameraSession: CameraSession = .init()) {
        self.cameraSession = cameraSession
        controls = CameraControlsController(cameraSession: cameraSession)
    }

    // MARK: - Lifecycle

    func start() async {
        do {
            try await cameraSession.start()
            availableCameras = await cameraSession.availableCameras()
            await controls.synchronizeWithCamera()
            cameraStatus = .running
        } catch {
            switch error {
            case .unauthorized:
                cameraStatus = .unauthorized
            case .setupFailed, .cameraNotFound, .addInputFailed,
                    .addOutputFailed, .configurationFailed:
                cameraStatus = .failed
            }
            print("Couldn't start capture: \(error.localizedDescription)")
        }
    }

    // MARK: - Photo Capture

    func captureAction() {
        guard !isPerformingCaptureOperation else { return }
        isPerformingCaptureOperation = true

        Task {
            defer { isPerformingCaptureOperation = false }

            let useCase = PhotoCaptureUseCase(
                photoCapture: cameraSession,
                photoSaving: DefaultPhotoLibrary()
            )

            do {
                let photo = try await useCase.execute(
                    flashMode: controls.settings.flashMode
                )
                capturedPhotoPreview = photo.previewImage
                isPhotoPreviewPresented = photo.previewImage != nil
            } catch {
                print("Couldn't capture photo: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Camera Selection

    func selectCamera(_ camera: Camera) {
        Task {
            do {
                try await cameraSession.selectCamera(id: camera.id)
                await controls.synchronizeWithCamera()
            } catch {
                print("Couldn't select camera: \(error.localizedDescription)")
            }
        }
    }
}
