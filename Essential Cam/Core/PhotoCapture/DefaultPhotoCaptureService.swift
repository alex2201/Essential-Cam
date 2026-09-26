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

    func supportsFlashMode(_ flashMode: CameraFlashMode) -> Bool {
        photoOutput.supportedFlashModes.contains(flashMode.avFoundationValue)
    }

    func capturePhoto(
        flashMode: CameraFlashMode,
        aspectRatio: CameraAspectRatio
    ) async throws -> Photo {
        defer { activeCaptureDelegate = nil }

        return try await withCheckedThrowingContinuation { continuation in
            let photoSettings = createPhotoSettings(flashMode: flashMode)
            let delegate = PhotoCaptureDelegate(
                aspectRatio: aspectRatio,
                continuation: continuation
            )

            activeCaptureDelegate = delegate
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }

    private func createPhotoSettings(flashMode: CameraFlashMode) -> AVCapturePhotoSettings {
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
        photoSettings.flashMode = flashMode.avFoundationValue

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
    private let aspectRatio: CameraAspectRatio
    private var photoData: Data?
    private var previewImage: CGImage?
    private var processingError: Error?

    /// Creates a new delegate object with the checked continuation to call when processing is complete.
    init(
        aspectRatio: CameraAspectRatio,
        continuation: PhotoContinuation
    ) {
        self.aspectRatio = aspectRatio
        self.continuation = continuation
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            processingError = error
            return
        }
        guard let capturedData = photo.fileDataRepresentation() else {
            processingError = PhotoCaptureError.noPhotoData
            return
        }

        do {
            photoData = try PhotoCropper.crop(capturedData, to: aspectRatio)
            previewImage = makeOrientedPreviewImage(from: photo)
                .flatMap { PhotoCropper.crop($0, to: aspectRatio) }
        } catch {
            processingError = error
        }
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

private enum PhotoCropper {
    private static let context = CIContext()

    static func crop(
        _ data: Data,
        to aspectRatio: CameraAspectRatio
    ) throws -> Data {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let sourceType = CGImageSourceGetType(source),
            let image = CIImage(
                data: data,
                options: [.applyOrientationProperty: true]
            )
        else {
            throw PhotoCaptureError.photoProcessingFailed
        }

        let cropRect = centeredCropRect(
            in: image.extent,
            aspectRatio: aspectRatio
        )
        let croppedImage = image.cropped(to: cropRect)

        guard let cgImage = context.createCGImage(croppedImage, from: cropRect) else {
            throw PhotoCaptureError.photoProcessingFailed
        }

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData,
            sourceType,
            1,
            nil
        ) else {
            throw PhotoCaptureError.photoProcessingFailed
        }

        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any]) ?? [:]
        properties[kCGImagePropertyOrientation] = CGImagePropertyOrientation.up.rawValue
        properties[kCGImagePropertyPixelWidth] = cgImage.width
        properties[kCGImagePropertyPixelHeight] = cgImage.height

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw PhotoCaptureError.photoProcessingFailed
        }

        return outputData as Data
    }

    static func crop(
        _ image: CGImage,
        to aspectRatio: CameraAspectRatio
    ) -> CGImage? {
        let imageRect = CGRect(
            x: 0,
            y: 0,
            width: image.width,
            height: image.height
        )
        let cropRect = centeredCropRect(
            in: imageRect,
            aspectRatio: aspectRatio
        ).integral

        return image.cropping(to: cropRect)
    }

    private static func centeredCropRect(
        in imageRect: CGRect,
        aspectRatio: CameraAspectRatio
    ) -> CGRect {
        let targetRatio = aspectRatio.widthToHeight(
            isPortrait: imageRect.height >= imageRect.width
        )
        let imageRatio = imageRect.width / imageRect.height

        if imageRatio > targetRatio {
            let width = imageRect.height * targetRatio
            return CGRect(
                x: imageRect.midX - width / 2,
                y: imageRect.minY,
                width: width,
                height: imageRect.height
            )
        }

        let height = imageRect.width / targetRatio
        return CGRect(
            x: imageRect.minX,
            y: imageRect.midY - height / 2,
            width: imageRect.width,
            height: height
        )
    }
}
