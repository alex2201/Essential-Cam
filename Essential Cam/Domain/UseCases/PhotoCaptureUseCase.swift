//
//  PhotoCaptureUseCase.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

protocol PhotoCapturing: Sendable {
    func capturePhoto(
        flashMode: CameraFlashMode,
        aspectRatio: CameraAspectRatio
    ) async throws -> Photo
}

protocol PhotoSaving: Sendable {
    func save(_ photo: Photo) async throws
}

struct PhotoCaptureUseCase {
    let photoCapture: any PhotoCapturing
    let photoSaving: any PhotoSaving

    // Returns proxy photo to show quick preview to the user
    func execute(
        flashMode: CameraFlashMode,
        aspectRatio: CameraAspectRatio
    ) async throws -> Photo {
        let photo = try await photoCapture.capturePhoto(
            flashMode: flashMode,
            aspectRatio: aspectRatio
        )
        try await photoSaving.save(photo)

        return photo
    }
}
