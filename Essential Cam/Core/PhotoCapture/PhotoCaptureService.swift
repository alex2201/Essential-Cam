//
//  PhotoCaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation

protocol PhotoCaptureService: CameraCaptureComponent {
    func supportsFlashMode(_ flashMode: CameraFlashMode) -> Bool
    func availablePhotoOutputFormats() -> [PhotoOutputFormat]
    func capturePhoto(
        flashMode: CameraFlashMode,
        aspectRatio: CameraAspectRatio,
        outputFormat: PhotoOutputFormat
    ) async throws -> Photo
}
