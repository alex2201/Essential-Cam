//
//  DefaultPhotoCaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation
import CoreImage
import ImageIO
import OSLog
import UniformTypeIdentifiers

private let photoCaptureLogger = Logger(
    subsystem: "com.alexanderlopez.Essential-Cam",
    category: "camera.capture"
)

final class DefaultPhotoCaptureService: PhotoCaptureService {
    var output: AVCaptureOutput {
        photoOutput
    }

    private let photoOutput = AVCapturePhotoOutput()
    private var activeCaptureDelegate: PhotoCaptureDelegate?
    private var supportedResolutions: [PhotoResolution] = []

    func supportsFlashMode(_ flashMode: CameraFlashMode) -> Bool {
        photoOutput.supportedFlashModes.contains(flashMode.avFoundationValue)
    }

    func updateConfiguration(for device: AVCaptureDevice) {
        photoOutput.isAppleProRAWEnabled = photoOutput.isAppleProRAWSupported
        photoOutput.isContentAwareDistortionCorrectionEnabled =
            photoOutput.isContentAwareDistortionCorrectionSupported
        supportedResolutions = device.activeFormat.supportedMaxPhotoDimensions
            .map { PhotoResolution(width: $0.width, height: $0.height) }
            .sorted { $0.megapixels < $1.megapixels }

        if let largestResolution = supportedResolutions.last {
            photoOutput.maxPhotoDimensions = CMVideoDimensions(
                width: largestResolution.width,
                height: largestResolution.height
            )
        }
    }

    func availablePhotoResolutions() -> [PhotoResolution] {
        supportedResolutions
    }

    func supportsContentAwareCorrection() -> Bool {
        photoOutput.isContentAwareDistortionCorrectionSupported
    }

    func availablePhotoOutputFormats() -> [PhotoOutputFormat] {
        var formats: [PhotoOutputFormat] = []

        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            formats.append(.heif)
        }
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            formats.append(.jpeg)
        }

        let destinationTypes = Set(
            CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        )
        if destinationTypes.contains(UTType.png.identifier) {
            formats.append(.png)
        }
        if destinationTypes.contains(UTType.tiff.identifier) {
            formats.append(.tiff)
        }

        let rawTypes = photoOutput.availableRawPhotoPixelFormatTypes
        if rawTypes.contains(where: AVCapturePhotoOutput.isBayerRAWPixelFormat) {
            formats.append(.raw)
        }
        if photoOutput.isAppleProRAWEnabled,
           rawTypes.contains(where: AVCapturePhotoOutput.isAppleProRAWPixelFormat) {
            formats.append(.appleProRAW)
        }

        return formats
    }

    func capturePhoto(
        flashMode: CameraFlashMode,
        aspectRatio: CameraAspectRatio,
        outputFormat: PhotoOutputFormat,
        resolution: PhotoResolution?,
        contentAwareCorrection: ContentAwareCorrection,
        previewHandler: @escaping @Sendable (CGImage) -> Void
    ) async throws -> Photo {
        defer { activeCaptureDelegate = nil }

        return try await withCheckedThrowingContinuation { continuation in
            guard let photoSettings = createPhotoSettings(
                flashMode: flashMode,
                outputFormat: outputFormat,
                resolution: resolution,
                contentAwareCorrection: contentAwareCorrection
            ) else {
                continuation.resume(throwing: PhotoCaptureError.photoProcessingFailed)
                return
            }
            let delegate = PhotoCaptureDelegate(
                aspectRatio: aspectRatio,
                outputFormat: outputFormat,
                previewHandler: previewHandler,
                continuation: continuation
            )

            activeCaptureDelegate = delegate
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }

    private func createPhotoSettings(
        flashMode: CameraFlashMode,
        outputFormat: PhotoOutputFormat,
        resolution: PhotoResolution?,
        contentAwareCorrection: ContentAwareCorrection
    ) -> AVCapturePhotoSettings? {
        let photoSettings: AVCapturePhotoSettings

        switch outputFormat {
        case .heif:
            guard photoOutput.availablePhotoCodecTypes.contains(.hevc) else { return nil }
            photoSettings = AVCapturePhotoSettings(
                format: [AVVideoCodecKey: AVVideoCodecType.hevc]
            )
        case .jpeg:
            guard photoOutput.availablePhotoCodecTypes.contains(.jpeg) else { return nil }
            photoSettings = AVCapturePhotoSettings(
                format: [AVVideoCodecKey: AVVideoCodecType.jpeg]
            )
        case .png, .tiff:
            let codec: AVVideoCodecType = photoOutput.availablePhotoCodecTypes.contains(.hevc)
                ? .hevc
                : .jpeg
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: codec])
        case .raw, .appleProRAW:
            let predicate = outputFormat == .appleProRAW
                ? AVCapturePhotoOutput.isAppleProRAWPixelFormat
                : AVCapturePhotoOutput.isBayerRAWPixelFormat
            guard let rawType = photoOutput.availableRawPhotoPixelFormatTypes.first(where: predicate)
            else { return nil }
            photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawType)
        }

        /// Set the format of the preview image to capture. The `photoSettings` object returns the available
        /// preview format types in order of compatibility with the primary image.
        if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }

        let supportedResolution = resolution.flatMap { requested in
            supportedResolutions.first(where: { $0 == requested })
        } ?? supportedResolutions.last
        if let supportedResolution {
            photoSettings.maxPhotoDimensions = CMVideoDimensions(
                width: supportedResolution.width,
                height: supportedResolution.height
            )
        }
        photoSettings.isAutoContentAwareDistortionCorrectionEnabled =
            contentAwareCorrection == .automatic
            && !outputFormat.isRAW
            && photoOutput.isContentAwareDistortionCorrectionEnabled
        if photoOutput.supportedFlashModes.contains(flashMode.avFoundationValue) {
            photoSettings.flashMode = flashMode.avFoundationValue
        }

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
    private let outputFormat: PhotoOutputFormat
    private let previewHandler: @Sendable (CGImage) -> Void
    private var photoData: Data?
    private var previewImage: CGImage?
    private var processingError: Error?

    /// Creates a new delegate object with the checked continuation to call when processing is complete.
    init(
        aspectRatio: CameraAspectRatio,
        outputFormat: PhotoOutputFormat,
        previewHandler: @escaping @Sendable (CGImage) -> Void,
        continuation: PhotoContinuation
    ) {
        self.aspectRatio = aspectRatio
        self.outputFormat = outputFormat
        self.previewHandler = previewHandler
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
            previewImage = makeOrientedPreviewImage(from: photo)
                .flatMap { PhotoCropper.crop($0, to: aspectRatio) }
            if let previewImage {
                previewHandler(previewImage)
            }

            photoData = try PhotoCropper.process(
                capturedData,
                to: aspectRatio,
                outputFormat: outputFormat
            )
        } catch {
            // TODO: Track this error with the integrated logging service.
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
        if let error {
            // TODO: Track this error with the integrated logging service.
            photoCaptureLogger.error(
                "Deferred photo proxy failed: \(error.localizedDescription, privacy: .public)"
            )
        } else {
            photoCaptureLogger.debug("Received a deferred photo proxy")
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // If an error occurs, resume the continuation by throwing an error, and return.
        if let error = error ?? processingError {
            // TODO: Track this error with the integrated logging service.
            continuation.resume(throwing: error)
            return
        }

        // If the app captures no photo data, resume the continuation by throwing an error, and return.
        guard let photoData else {
            // TODO: Track this error with the integrated logging service.
            continuation.resume(throwing: PhotoCaptureError.noPhotoData)
            return
        }

        /// Create a photo object to save to the `MediaLibrary`.
        let photo = Photo(
            data: photoData,
            previewImage: previewImage,
            uniformTypeIdentifier: outputFormat.uniformType.identifier
        )
        // Resume the continuation by returning the captured photo.
        continuation.resume(returning: photo)
    }
}

enum PhotoCropper {
    private static let context = CIContext()

    static func process(
        _ data: Data,
        to aspectRatio: CameraAspectRatio,
        outputFormat: PhotoOutputFormat
    ) throws -> Data {
        if outputFormat.isRAW {
            return data
        }

        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
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
            outputFormat.uniformType.identifier as CFString,
            1,
            nil
        ) else {
            throw PhotoCaptureError.photoProcessingFailed
        }

        var properties = outputProperties(
            copiedFrom: source,
            outputFormat: outputFormat
        )
        properties[kCGImagePropertyOrientation] = CGImagePropertyOrientation.up.rawValue
        properties[kCGImagePropertyPixelWidth] = cgImage.width
        properties[kCGImagePropertyPixelHeight] = cgImage.height

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw PhotoCaptureError.photoProcessingFailed
        }

        return outputData as Data
    }

    private static func outputProperties(
        copiedFrom source: CGImageSource,
        outputFormat: PhotoOutputFormat
    ) -> [CFString: Any] {
        // PNG stores orientation in an eXIf chunk. Copying all metadata from the
        // HEIF/JPEG capture can leave the original orientation in that chunk even
        // though Core Image has already rotated the pixels. Photos then applies the
        // orientation a second time. Start PNG metadata clean and explicitly mark
        // the rendered pixels as upright below.
        guard outputFormat != .png else { return [:] }

        return (CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any]) ?? [:]
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

private extension PhotoOutputFormat {
    var uniformType: UTType {
        switch self {
        case .heif:
            .heic
        case .jpeg:
            .jpeg
        case .png:
            .png
        case .tiff:
            .tiff
        case .raw, .appleProRAW:
            .dng
        }
    }
}
