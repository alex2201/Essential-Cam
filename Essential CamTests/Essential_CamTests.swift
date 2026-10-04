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
        var configuredSettings = settings
        configuredSettings.photoResolution = PhotoResolution(width: 8_064, height: 6_048)
        configuredSettings.photoTimer = .fiveSeconds
        configuredSettings.contentAwareCorrection = .automatic

        let data = try JSONEncoder().encode(configuredSettings)
        let decodedSettings = try JSONDecoder().decode(CameraSettings.self, from: data)

        #expect(decodedSettings == configuredSettings)
    }

    @Test @MainActor func cameraSettingsStorePersistsAndRestores() throws {
        let suiteName = "EssentialCamTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CameraSettingsStore(defaults: defaults)
        var settings = CameraSettings.standard
        settings.aspectRatio = .square
        settings.photoOutputFormat = .tiff
        settings.photoResolution = PhotoResolution(width: 4_032, height: 3_024)
        settings.photoTimer = .tenSeconds
        settings.contentAwareCorrection = .automatic
        settings.zoomFactor = 2

        store.save(settings)

        #expect(store.load() == settings)
    }

    @Test func cameraPresetSettingsCaptureNonDefaultPhotoSettings() {
        var settings = CameraSettings.standard
        settings.exposure = .manual(iso: 400, durationInSeconds: 1.0 / 125.0)
        settings.focus = .manual(lensPosition: 0.75)
        settings.whiteBalance = .manual(temperature: 5_600, tint: 10)
        settings.aspectRatio = .square
        settings.flashMode = .automatic
        settings.zoomFactor = 2
        settings.captureMode = .video
        settings.photoOutputFormat = .raw

        let presetSettings = CameraPresetSettings(settings: settings)

        #expect(presetSettings.exposure == settings.exposure)
        #expect(presetSettings.focus == settings.focus)
        #expect(presetSettings.whiteBalance == settings.whiteBalance)
        #expect(presetSettings.aspectRatio == .square)
        #expect(presetSettings.flashMode == .automatic)
    }

    @Test func cameraPresetSettingsPreserveDefaultsAndRepresentLockedValuesAsNil() {
        var settings = CameraSettings.standard
        settings.focus = .locked
        settings.whiteBalance = .locked

        let presetSettings = CameraPresetSettings(settings: settings)

        #expect(presetSettings.exposure == CameraSettings.standard.exposure)
        #expect(presetSettings.focus == nil)
        #expect(presetSettings.whiteBalance == nil)
        #expect(presetSettings.aspectRatio == CameraSettings.standard.aspectRatio)
        #expect(presetSettings.flashMode == CameraSettings.standard.flashMode)
    }

    @Test func cameraPresetSettingsRoundTripThroughJSON() throws {
        let presetSettings = CameraPresetSettings(
            exposure: .automatic(exposureBias: 1),
            focus: nil,
            whiteBalance: .manual(temperature: 4_500, tint: -5),
            aspectRatio: .sixteenByNine,
            flashMode: .on
        )

        let data = try JSONEncoder().encode(presetSettings)
        let decodedSettings = try JSONDecoder().decode(
            CameraPresetSettings.self,
            from: data
        )

        #expect(decodedSettings == presetSettings)
    }

    @Test func cameraPresetRepositoryPersistsAndRestoresPresets() async throws {
        let fileURL = temporaryFileURL(named: "presets.json")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let firstPreset = CameraPreset(
            name: "Street",
            settings: CameraPresetSettings(
                exposure: .manual(iso: 200, durationInSeconds: 1.0 / 250.0),
                aspectRatio: .fourByThree
            )
        )
        let secondPreset = CameraPreset(
            name: "Night",
            settings: CameraPresetSettings(
                exposure: .manual(iso: 800, durationInSeconds: 1.0 / 30.0),
                flashMode: .off
            )
        )
        let repository = JSONCameraPresetRepository(fileURL: fileURL)

        try await repository.save(firstPreset)
        try await repository.save(secondPreset)

        let restoredRepository = JSONCameraPresetRepository(fileURL: fileURL)
        #expect(try await restoredRepository.presets() == [firstPreset, secondPreset])
    }

    @Test func cameraPresetRepositoryUpdatesWithoutChangingOrder() async throws {
        let fileURL = temporaryFileURL(named: "presets.json")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let firstPreset = CameraPreset(name: "First", settings: .init())
        let secondPreset = CameraPreset(name: "Second", settings: .init())
        let repository = JSONCameraPresetRepository(fileURL: fileURL)
        try await repository.save(firstPreset)
        try await repository.save(secondPreset)

        var updatedFirstPreset = firstPreset
        updatedFirstPreset.name = "Updated"
        try await repository.save(updatedFirstPreset)

        #expect(try await repository.presets() == [updatedFirstPreset, secondPreset])
    }

    @Test func cameraPresetRepositoryDeletesPersistedPreset() async throws {
        let fileURL = temporaryFileURL(named: "presets.json")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let firstPreset = CameraPreset(name: "First", settings: .init())
        let secondPreset = CameraPreset(name: "Second", settings: .init())
        let repository = JSONCameraPresetRepository(fileURL: fileURL)
        try await repository.save(firstPreset)
        try await repository.save(secondPreset)

        try await repository.delete(id: firstPreset.id)

        let restoredRepository = JSONCameraPresetRepository(fileURL: fileURL)
        #expect(try await restoredRepository.presets() == [secondPreset])
    }

    @Test @MainActor func cameraPresetStoreSavesUpdatesDeletesAndReordersPresets() {
        let first = CameraPreset(name: "First", settings: .init())
        let second = CameraPreset(name: "Second", settings: .init())
        let store = CameraPresetStore()

        store.save(first)
        store.save(second)
        store.select(id: first.id)
        #expect(store.selectedPresetID == first.id)
        store.clearSelection()
        #expect(store.selectedPresetID == nil)
        var customSettings = CameraSettings.standard
        customSettings.aspectRatio = .square
        store.updateUnselectedSettings(customSettings)
        #expect(store.unselectedSettings.aspectRatio == .square)
        store.select(id: first.id)
        var ignoredSettings = customSettings
        ignoredSettings.aspectRatio = .sixteenByNine
        store.updateUnselectedSettings(ignoredSettings)
        #expect(store.unselectedSettings.aspectRatio == .square)
        var renamedFirst = first
        renamedFirst.name = "Renamed"
        store.save(renamedFirst)

        #expect(store.presets.map(\.name) == ["Renamed", "Second"])

        store.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(store.presets.map(\.name) == ["Second", "Renamed"])

        store.delete(id: second.id)
        #expect(store.presets == [renamedFirst])

        store.delete(id: first.id)
        #expect(store.selectedPresetID == nil)
    }

    @Test @MainActor func cameraPresetStoreLoadsAndPersistsMutations() async throws {
        let fileURL = temporaryFileURL(named: "presets.json")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let repository = JSONCameraPresetRepository(fileURL: fileURL)
        let firstPreset = CameraPreset(name: "First", settings: .init())
        let secondPreset = CameraPreset(name: "Second", settings: .init())
        try await repository.replaceAll(with: [firstPreset])
        let store = CameraPresetStore(repository: repository)

        await store.load()
        store.save(secondPreset)
        store.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        store.delete(id: firstPreset.id)
        await store.waitForPendingPersistence()

        let restoredRepository = JSONCameraPresetRepository(fileURL: fileURL)
        #expect(store.persistenceErrorDescription == nil)
        #expect(try await restoredRepository.presets() == [secondPreset])
    }

#if DEBUG
    @Test func debugCameraPresetsProvideStableCoverageFixtures() {
        let presets = CameraPreset.debugSamples

        #expect(presets.count == 4)
        #expect(Set(presets.map(\.id)).count == presets.count)
        #expect(presets.contains { $0.settings.exposure?.exposureBias != nil })
        #expect(presets.contains { preset in
            if case .some(.manual) = preset.settings.exposure { return true }
            return false
        })
        #expect(presets.contains { $0.settings.focus == nil })
        #expect(
            Set(presets.compactMap(\.settings.aspectRatio))
                == Set([CameraAspectRatio.square, .fourByThree, .sixteenByNine])
        )
    }
#endif

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

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
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
        resolution: PhotoResolution?,
        contentAwareCorrection: ContentAwareCorrection,
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
