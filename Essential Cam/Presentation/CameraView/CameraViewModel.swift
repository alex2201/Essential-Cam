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
        } catch {
            switch error {
            case .unauthorized:
                cameraStatus = .unauthorized
            case .setupFailed, .addInputFailed, .addOutputFailed:
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

            let useCase = PhotoCaptureUseCase(photoCapture: cameraSession)

            do {
                _ = try await useCase.execute()
            } catch {
                print("Couldn't capture photo: \(error.localizedDescription)")
            }
        }
    }
}
