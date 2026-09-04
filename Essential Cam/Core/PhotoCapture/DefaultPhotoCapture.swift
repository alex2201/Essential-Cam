//
//  DefaultPhotoCapture.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation

final class DefaultPhotoCapture: PhotoCapture {
    let output = AVCapturePhotoOutput()

    func capturePhoto() async throws -> Photo {
        try await withCheckedThrowingContinuation { continuation in
            let photoSettings = createPhotoSettings()
            let delegate = PhotoCaptureDelegate(continuation: continuation)
            output.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }

    private func createPhotoSettings() -> AVCapturePhotoSettings {
        // Create a new settings object to configure the photo capture.
        var photoSettings = AVCapturePhotoSettings()

        // Capture photos in HEIF format when the device supports it.
        if output.availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }

        /// Set the format of the preview image to capture. The `photoSettings` object returns the available
        /// preview format types in order of compatibility with the primary image.
        if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }

        photoSettings.maxPhotoDimensions = output.maxPhotoDimensions
        photoSettings.photoQualityPrioritization = .quality

        return photoSettings
    }
}

// MARK: - A photo capture delegate to process the captured photo.

/// An object that adopts the `AVCapturePhotoCaptureDelegate` protocol to respond to photo capture life-cycle events.
///
/// The delegate produces a stream of events that indicate its current state of processing.
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {

    typealias PhotoContinuation = CheckedContinuation<Photo, Error>

    private let continuation: PhotoContinuation

    private var photoData: Data?

    /// Creates a new delegate object with the checked continuation to call when processing is complete.
    init(continuation: PhotoContinuation) {
        self.continuation = continuation
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
        photoData = photo.fileDataRepresentation()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // If an error occurs, resume the continuation by throwing an error, and return.
        if let error {
            continuation.resume(throwing: error)
            return
        }

        // If the app captures no photo data, resume the continuation by throwing an error, and return.
        guard let photoData else {
            continuation.resume(throwing: PhotoCaptureError.noPhotoData)
            return
        }

        /// Create a photo object to save to the `MediaLibrary`.
        let photo = Photo(data: photoData)
        // Resume the continuation by returning the captured photo.
        continuation.resume(returning: photo)
    }
}
