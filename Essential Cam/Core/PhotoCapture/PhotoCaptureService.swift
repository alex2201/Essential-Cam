//
//  PhotoCaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation
import CoreGraphics

protocol PhotoCaptureService: CameraCaptureComponent {
    func supportsFlashMode(_ flashMode: CameraFlashMode) -> Bool
    func availablePhotoOutputFormats() -> [PhotoOutputFormat]
    func availablePhotoResolutions() -> [PhotoResolution]
    func supportsContentAwareCorrection() -> Bool
    func capturePhoto(
        flashMode: CameraFlashMode,
        aspectRatio: CameraAspectRatio,
        outputFormat: PhotoOutputFormat,
        resolution: PhotoResolution?,
        contentAwareCorrection: ContentAwareCorrection,
        previewHandler: @escaping @Sendable (CGImage) -> Void
    ) async throws -> Photo
}
