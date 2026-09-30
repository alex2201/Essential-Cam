//
//  Essential_CamTests.swift
//  Essential CamTests
//
//  Created by Alexander López on 01/09/26.
//

import Foundation
import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Essential_Cam

struct Essential_CamTests {

    @Test func cameraSettingsRoundTripThroughJSON() throws {
        let settings = CameraSettings(
            exposure: .manual(iso: 400, durationInSeconds: 1.0 / 125.0),
            focus: .manual(lensPosition: 0.75),
            whiteBalance: .manual(temperature: 5_600, tint: 10),
            zoomFactor: 2,
            captureMode: .photo,
            aspectRatio: .fourByThree,
            flashMode: .automatic
        )

        let data = try JSONEncoder().encode(settings)
        let decodedSettings = try JSONDecoder().decode(CameraSettings.self, from: data)

        #expect(decodedSettings == settings)
    }

    @Test @MainActor func cameraSettingsStorePersistsAndRestores() throws {
        let suiteName = "EssentialCamTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CameraSettingsStore(defaults: defaults)
        var settings = CameraSettings.standard
        settings.aspectRatio = .square
        settings.photoOutputFormat = .tiff
        settings.zoomFactor = 2

        store.save(settings)

        #expect(store.load() == settings)
    }

    @Test func pendingPhotoSurvivesStoreRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = Photo(
            data: Data([0x01, 0x02, 0x03]),
            previewImage: nil,
            uniformTypeIdentifier: "public.jpeg"
        )

        try await PendingPhotoStore(directoryURL: directory).save(photo)
        let restored = try await PendingPhotoStore(directoryURL: directory).load()

        #expect(restored?.data == photo.data)
        #expect(restored?.uniformTypeIdentifier == photo.uniformTypeIdentifier)
    }

    @Test func pendingPhotoIsNotOverwrittenByAnotherCapture() async throws {
        let photo = makePhoto([0x01])
        let capture = PhotoCaptureSpy(photo: photo)
        let library = PhotoSavingSpy(error: PhotoCaptureError.photoLibrarySaveFailed)
        let pendingStore = PendingPhotoStoreSpy()
        let coordinator = makeCoordinator(
            capture: capture,
            library: library,
            pendingStore: pendingStore
        )

        await #expect(throws: PhotoCaptureWorkflowError.photoLibrarySaveFailed) {
            try await coordinator.capture(settings: .standard)
        }
        await #expect(throws: PhotoCaptureWorkflowError.pendingPhotoAlreadyExists) {
            try await coordinator.capture(settings: .standard)
        }

        #expect(await capture.captureCount == 1)
        #expect(await pendingStore.savedPhoto?.data == photo.data)
    }

    @Test func retrySavesAndDiscardsPendingPhoto() async throws {
        let photo = makePhoto([0x02])
        let capture = PhotoCaptureSpy(photo: photo)
        let library = PhotoSavingSpy(error: PhotoCaptureError.photoLibrarySaveFailed)
        let pendingStore = PendingPhotoStoreSpy()
        let coordinator = makeCoordinator(
            capture: capture,
            library: library,
            pendingStore: pendingStore
        )

        await #expect(throws: PhotoCaptureWorkflowError.photoLibrarySaveFailed) {
            try await coordinator.capture(settings: .standard)
        }
        await library.setError(nil)
        let savedPhoto = try await coordinator.retryPendingSave()

        #expect(savedPhoto.data == photo.data)
        #expect(await coordinator.hasPendingPhoto() == false)
        #expect(await pendingStore.savedPhoto == nil)
        #expect(await library.saveCount == 2)
    }

    @Test func pendingStoreFailureIsNotReportedAsCaptureFailure() async {
        let capture = PhotoCaptureSpy(photo: makePhoto([0x03]))
        let library = PhotoSavingSpy()
        let pendingStore = PendingPhotoStoreSpy(saveError: TestError.expected)
        let coordinator = makeCoordinator(
            capture: capture,
            library: library,
            pendingStore: pendingStore
        )

        await #expect(throws: PhotoCaptureWorkflowError.pendingStorageFailed) {
            try await coordinator.capture(settings: .standard)
        }
        #expect(await coordinator.hasPendingPhoto())
        #expect(await library.saveCount == 0)
    }

    @Test func restoredPendingPhotoCanBeDiscarded() async throws {
        let pendingStore = PendingPhotoStoreSpy(photo: makePhoto([0x04]))
        let coordinator = makeCoordinator(
            capture: PhotoCaptureSpy(photo: makePhoto([0x05])),
            library: PhotoSavingSpy(),
            pendingStore: pendingStore
        )

        #expect(try await coordinator.restorePendingPhoto() != nil)
        try await coordinator.discardPendingPhoto()

        #expect(await coordinator.hasPendingPhoto() == false)
        #expect(await pendingStore.savedPhoto == nil)
    }

    @Test @MainActor func lifecyclePreservesRecoveryCauseUntilOperationFinishes() {
        let lifecycle = CameraLifecycleController()

        let immediateRecovery = lifecycle.recoveryToRun(
            for: .mediaServicesReset,
            operationInProgress: true
        )

        #expect(immediateRecovery == nil)
        #expect(lifecycle.takePendingRecovery() == .mediaServicesReset)
        #expect(lifecycle.takePendingRecovery() == nil)
    }

    @Test @MainActor func backgroundClearsQueuedRecovery() {
        let lifecycle = CameraLifecycleController()
        _ = lifecycle.recoveryToRun(
            for: .unknown,
            operationInProgress: true
        )

        #expect(lifecycle.updateScene(isActive: false, isBackground: true) == false)
        #expect(lifecycle.takePendingRecovery() == nil)
    }

    @Test func pngExportBakesOrientationIntoPixelsWithoutRotatingMetadata() throws {
        let sourceData = try makeJPEG(width: 4, height: 2, orientation: .right)

        let pngData = try PhotoCropper.process(
            sourceData,
            to: .fourByThree,
            outputFormat: .png
        )

        let source = try #require(CGImageSourceCreateWithData(pngData as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )

        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(height > width)
        #expect(properties[kCGImagePropertyOrientation] as? UInt32 == CGImagePropertyOrientation.up.rawValue)
    }

    private func makeJPEG(
        width: Int,
        height: Int,
        orientation: CGImagePropertyOrientation
    ) throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(
                data,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        )
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
        )
        #expect(CGImageDestinationFinalize(destination))

        return data as Data
    }

    private func makePhoto(_ bytes: [UInt8]) -> Photo {
        Photo(
            data: Data(bytes),
            previewImage: nil,
            uniformTypeIdentifier: "public.jpeg"
        )
    }

    private func makeCoordinator(
        capture: PhotoCaptureSpy,
        library: PhotoSavingSpy,
        pendingStore: PendingPhotoStoreSpy
    ) -> PhotoCaptureCoordinator {
        PhotoCaptureCoordinator(
            photoCapture: capture,
            photoSaving: library,
            pendingStore: pendingStore
        )
    }

}

private enum TestError: Error {
    case expected
}

private actor PhotoCaptureSpy: PhotoCapturing {
    private let photo: Photo
    private(set) var captureCount = 0

    init(photo: Photo) {
        self.photo = photo
    }

    func capturePhoto(
        flashMode: CameraFlashMode,
        aspectRatio: CameraAspectRatio,
        outputFormat: PhotoOutputFormat,
        previewHandler: @escaping @Sendable (CGImage) -> Void
    ) async throws -> Photo {
        captureCount += 1
        return photo
    }
}

private actor PhotoSavingSpy: PhotoSaving {
    private var error: Error?
    private(set) var saveCount = 0

    init(error: Error? = nil) {
        self.error = error
    }

    func setError(_ error: Error?) {
        self.error = error
    }

    func save(_ photo: Photo) async throws {
        saveCount += 1
        if let error { throw error }
    }
}

private actor PendingPhotoStoreSpy: PendingPhotoStoring {
    private(set) var savedPhoto: Photo?
    private let saveError: Error?

    init(photo: Photo? = nil, saveError: Error? = nil) {
        savedPhoto = photo
        self.saveError = saveError
    }

    func save(_ photo: Photo) async throws {
        if let saveError { throw saveError }
        savedPhoto = photo
    }

    func load() async throws -> Photo? {
        savedPhoto
    }

    func discard() async throws {
        savedPhoto = nil
    }
}
