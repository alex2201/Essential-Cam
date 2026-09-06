//
//  DefaultPhotoCaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation
import CoreImage
import ImageIO

final class DefaultPhotoCaptureService: PhotoCaptureService {
    var output: AVCaptureOutput {
        photoOutput
    }

    private let photoOutput = AVCapturePhotoOutput()
    private var activeCaptureDelegate: PhotoCaptureDelegate?

    func capturePhoto() async throws -> Photo {
        defer { activeCaptureDelegate = nil }

        return try await withCheckedThrowingContinuation { continuation in
            let photoSettings = createPhotoSettings()
            let delegate = PhotoCaptureDelegate(continuation: continuation)

            activeCaptureDelegate = delegate
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }

    private func createPhotoSettings() -> AVCapturePhotoSettings {
        // Create a new settings object to configure the photo capture.
        var photoSettings = AVCapturePhotoSettings()

        // Capture photos in HEIF format when the device supports it.
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }

        /// Set the format of the preview image to capture. The `photoSettings` object returns the available
        /// preview format types in order of compatibility with the primary image.
        if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }

        photoSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions

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
    private var previewImage: CGImage?
    private var processingError: Error?

    /// Creates a new delegate object with the checked continuation to call when processing is complete.
    init(continuation: PhotoContinuation) {
        self.continuation = continuation
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            processingError = error
            return
        }
        photoData = photo.fileDataRepresentation()
        previewImage = makeOrientedPreviewImage(from: photo)
    }

    private func makeOrientedPreviewImage(from photo: AVCapturePhoto) -> CGImage? {
        guard let previewImage = photo.previewCGImageRepresentation() else {
            return nil
        }

        guard
            let orientationValue = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
            let orientation = CGImagePropertyOrientation(rawValue: orientationValue),
            orientation != .up
        else {
            return previewImage
        }

        let orientedPreview = CIImage(cgImage: previewImage)
            .oriented(orientation)

        return CIContext().createCGImage(
            orientedPreview,
            from: orientedPreview.extent
        )
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCapturingDeferredPhotoProxy deferredPhotoProxy: AVCaptureDeferredPhotoProxy?, error: (any Error)?) {
        print("Received a deferred photo proxy")
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // If an error occurs, resume the continuation by throwing an error, and return.
        if let error = error ?? processingError {
            continuation.resume(throwing: error)
            return
        }

        // If the app captures no photo data, resume the continuation by throwing an error, and return.
        guard let photoData else {
            continuation.resume(throwing: PhotoCaptureError.noPhotoData)
            return
        }

        /// Create a photo object to save to the `MediaLibrary`.
        let photo = Photo(data: photoData, previewImage: previewImage)
        // Resume the continuation by returning the captured photo.
        continuation.resume(returning: photo)
    }
}
