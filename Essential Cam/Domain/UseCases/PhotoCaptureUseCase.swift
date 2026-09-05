//
//  PhotoCaptureUseCase.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

struct PhotoCaptureUseCase {
    let photoCapture: any PhotoCapturing

    func execute() async throws -> Photo {
        try await photoCapture.capturePhoto()
    }
}
