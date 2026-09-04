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
    let captureSession: AVCaptureSession

    private let cameraSession: CameraSession

    init(
        cameraSession: CameraSession = .init()
    ) {
        captureSession = cameraSession.captureSession
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
}
