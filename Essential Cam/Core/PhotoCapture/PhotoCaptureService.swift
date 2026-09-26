//
//  PhotoCaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation

protocol PhotoCaptureService: CameraCaptureComponent {
    func supportsFlashMode(_ flashMode: CameraFlashMode) -> Bool
    func capturePhoto(
        flashMode: CameraFlashMode,
        aspectRatio: CameraAspectRatio
    ) async throws -> Photo
}
