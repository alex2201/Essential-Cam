//
//  CameraViewModel.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation
import Foundation

@MainActor
@Observable
class CameraViewModel {

    var cameraStatus = CameraStatus.unknown
    var previewSource: PreviewSource {
        captureService.previewSource
    }

    private let captureService: CaptureService

    init(
        captureService: CaptureService = .init()
    ) {
        self.captureService = captureService
    }

    func start() async {
        do {
            try await captureService.start()
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
