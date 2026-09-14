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
class CameraViewModel {

    var cameraStatus = CameraStatus.unknown
    var isPerformingCaptureOperation = false
    var capturedPhotoPreview: CGImage?
    var isPhotoPreviewPresented = false
    var cameraSettings = CameraSettings.standard {
        didSet {
            guard cameraSettings != oldValue else { return }
            applyCameraSettings()
        }
    }
    private(set) var captureOrientation = CaptureOrientation.portrait
    private(set) var availableCameras: [Camera] = []

    var captureSession: AVCaptureSession {
        cameraSession.captureSession
    }

    private let cameraSession: CameraSession

    init(
        cameraSession: CameraSession = .init()
    ) {
        self.cameraSession = cameraSession
    }

    func start() async {
        do {
            try await cameraSession.start()
            cameraStatus = .running
            availableCameras = await cameraSession.availableCameras()
            applyCameraSettings()
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
                let photo = try await useCase.execute()
                capturedPhotoPreview = photo.previewImage
                isPhotoPreviewPresented = photo.previewImage != nil
            } catch {
                print("Couldn't capture photo: \(error.localizedDescription)")
            }
        }
    }

    func selectCamera(_ camera: Camera) {
        Task {
            do {
                try await cameraSession.selectCamera(id: camera.id)
                try await cameraSession.apply(cameraSettings)
            } catch {
                print("Couldn't select camera: \(error.localizedDescription)")
            }
        }
    }

    private func applyCameraSettings() {
        let settings = cameraSettings

        Task {
            do {
                try await cameraSession.apply(settings)
            } catch {
                print("Couldn't apply camera settings: \(error.localizedDescription)")
            }
        }
    }
}
