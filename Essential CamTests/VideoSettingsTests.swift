//
//  VideoSettingsTests.swift
//  Essential CamTests
//
//  Created by Alexander López.
//

import Foundation
import Testing
@testable import Essential_Cam

struct VideoSettingsTests {
    @Test @MainActor func discoveringConnectedMicrophonesUpdatesListWithoutSelectingThem() async {
        let controls = CameraControlsController(cameraSession: CameraSession(),
            settingsThrottler: IgnoredCameraSettings(), zoomThrottler: IgnoredCameraSettings())
        await controls.synchronizeWithCamera()
        let photo = controls.settings
        let phone = VideoMicrophone(id: "phone", name: "iPhone", isBuiltIn: true)
        let external = VideoMicrophone(id: "usb", name: "USB", isBuiltIn: false)
        await controls.reconcileVideoMicrophones([phone])
        await controls.reconcileVideoMicrophones([phone, external])
        #expect(controls.videoCapabilities.microphones == [phone, external])
        #expect(controls.settings == photo)
        await controls.switchCaptureMode(.video)
        #expect(controls.settings.video.microphone == .automatic)
        // Closing the settings surface cancels its ongoing discovery task.
        let monitoring = Task { await controls.monitorVideoMicrophones() }
        await Task.yield()
        monitoring.cancel()
        await monitoring.value
        controls.cancelPendingChanges()
    }

    @Test func microphoneFallbackRestoresLastAvailableChoiceAndNeverAutomaticallyReselects() {
        let phone = VideoMicrophone(id: "phone", name: "iPhone", isBuiltIn: true)
        let first = VideoMicrophone(id: "first", name: "USB A", isBuiltIn: false)
        let second = VideoMicrophone(id: "second", name: "USB B", isBuiltIn: false)
        var history = VideoMicrophoneFallbackHistory()
        history.rememberChange(from: .automatic, to: .iPhone)
        history.rememberChange(from: .iPhone, to: first.selection)
        history.rememberChange(from: first.selection, to: second.selection)
        #expect(history.fallback(for: second.selection, inputs: [phone, first]) == first.selection)
        #expect(history.fallback(for: second.selection, inputs: [phone]) == .iPhone)
        #expect(history.fallback(for: second.selection, inputs: []) == .automatic)
        #expect(history.fallback(for: second.selection, inputs: [phone, second]) == nil)
        #expect(history.fallback(for: .automatic, inputs: [phone, first, second]) == nil)
        #expect(history.fallback(for: .iPhone, inputs: [phone, first]) == nil)
        let withoutHistory = VideoMicrophoneFallbackHistory()
        #expect(withoutHistory.fallback(for: first.selection, inputs: [phone]) == .automatic)
    }

    @Test @MainActor func controllerReconcilesDisconnectionWithoutChangingPhotoOrPreset() async {
        let controls = CameraControlsController(cameraSession: CameraSession(),
            settingsThrottler: IgnoredCameraSettings(), zoomThrottler: IgnoredCameraSettings())
        await controls.synchronizeWithCamera()
        controls.setPhotoTimer(.tenSeconds)
        let photo = controls.settings
        await controls.switchCaptureMode(.video)
        var video = controls.settings.video
        video.microphone = .iPhone
        controls.setVideoSettings(video)
        await Task.yield()
        while controls.isApplyingConfiguration { await Task.yield() }
        video.microphone = .external(id: "usb", name: "USB")
        video.resolution = .ultraHD
        controls.setVideoSettings(video)
        await Task.yield()
        while controls.isApplyingConfiguration { await Task.yield() }
        let preset = CameraPreset(name: "External", settings: CameraPresetSettings(settings: controls.settings))
        let repository = MemoryPresetRepository()
        let store = CameraPresetStore(presets: [preset], repository: repository)
        store.activate(.video)
        store.select(id: preset.id, currentSettings: controls.settings)
        let phone = VideoMicrophone(id: "phone", name: "iPhone", isBuiltIn: true)
        let external = VideoMicrophone(id: "usb", name: "USB", isBuiltIn: false)
        await controls.reconcileVideoMicrophones([phone, external])
        #expect(controls.settings.video.microphone == external.selection)
        await controls.reconcileVideoMicrophones([phone])
        #expect(controls.settings.video.microphone == .iPhone)
        #expect(controls.settings.video.resolution == .ultraHD)
        store.updateUnselectedSettings(controls.settings)
        await store.waitForPendingPersistence()
        #expect(store.selectedPresetID == nil)
        #expect(store.modePresets.first?.settings.video?.microphone == external.selection)
        #expect(await repository.replacements == 0)
        #expect(controls.configurationNotice != nil)
        await controls.reconcileVideoMicrophones([phone, external])
        #expect(controls.settings.video.microphone == .iPhone)
        await controls.switchCaptureMode(.photo)
        #expect(controls.settings == photo)
        await controls.reconcileVideoMicrophones([])
        #expect(controls.settings == photo)
        await controls.switchCaptureMode(.video)
        #expect(controls.settings.video.microphone == .automatic)
        controls.cancelPendingChanges()
    }

    @Test func microphoneSelectionsResolveByIdentityAndHandleDisconnectedInputs() throws {
        let phone = VideoMicrophone(id: "phone", name: "iPhone", isBuiltIn: true)
        let external = VideoMicrophone(id: "usb", name: "USB Microphone", isBuiltIn: false)
        let requested = VideoMicrophoneSelection.external(id: "usb", name: "Old Name")
        #expect(requested.resolvedInput(in: [phone, external]) == external)
        #expect(requested == external.selection)
        #expect(Set([requested, external.selection]).count == 1)
        #expect(requested.isUnavailable(in: [phone]))
        #expect(requested.resolvedInput(in: [phone]) == nil)
        #expect(VideoMicrophoneSelection.iPhone.resolvedInput(in: [external, phone]) == phone)
        #expect(VideoMicrophoneSelection.iPhone.isUnavailable(in: [external]))
        #expect(!VideoMicrophoneSelection.automatic.isUnavailable(in: []))
        #expect(VideoMicrophoneSelection.automatic.resolvedInput(in: [external, phone]) == nil)
        var settings = VideoSettings.standard
        settings.microphone = requested
        let decoded = try JSONDecoder().decode(VideoSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.microphone == requested)
        #expect(decoded.microphone.displayName == "Old Name")
        let legacy = Data(#"{"resolution":"ultraHD","frameRate":60,"codec":"hevc","stabilization":"off","torch":true}"#.utf8)
        let migrated = try JSONDecoder().decode(VideoSettings.self, from: legacy)
        #expect(migrated.microphone == .automatic)
        #expect(migrated.resolution == .ultraHD && migrated.frameRate == .fps60)
    }

    @Test func captureProfilesKeepAllCameraValuesIndependent() {
        var profiles = CaptureSettingsProfiles()
        var photo = profiles[.photo]
        photo.exposure = .manual(iso: 800, durationInSeconds: 0.5)
        photo.photoOutputFormat = .raw
        photo.photoTimer = .tenSeconds
        profiles[.photo] = photo
        var video = profiles[.video]
        video.exposure = .manual(iso: 100, durationInSeconds: 1 / 60)
        video.focus = .manual(lensPosition: 0.7)
        video.whiteBalance = .manual(temperature: 4500, tint: 10)
        video.video.resolution = .ultraHD
        video.video.frameRate = .fps60
        video.zoomFactor = 2
        profiles[.video] = video
        #expect(profiles[.photo] == photo)
        #expect(profiles[.video] == video)
        #expect(CaptureSettingsProfiles()[.photo] == .standard)
        #expect(CaptureSettingsProfiles()[.video] == .standard(for: .video))
    }

    @Test @MainActor func controllerRestoresPhotoAndVideoProfilesAcrossRepeatedSwitches() async {
        let controls = CameraControlsController(cameraSession: CameraSession(),
            settingsThrottler: IgnoredCameraSettings(), zoomThrottler: IgnoredCameraSettings())
        await controls.synchronizeWithCamera()
        controls.setManualExposureISO(700)
        controls.setManualExposureDuration(0.4)
        controls.setAspectRatio(.square)
        controls.setPhotoTimer(.tenSeconds)
        let photo = controls.settings
        await controls.switchCaptureMode(.video)
        controls.setManualExposureISO(100)
        controls.setManualExposureDuration(1 / 60)
        var videoOutput = controls.settings.video
        videoOutput.codec = .hevc
        controls.setVideoSettings(videoOutput)
        // Allow the configuration task to run before switching back.
        await Task.yield()
        while controls.isApplyingConfiguration { await Task.yield() }
        let video = controls.settings
        await controls.switchCaptureMode(.photo)
        #expect(controls.settings == photo)
        await controls.switchCaptureMode(.video)
        #expect(controls.settings == video)
        controls.cancelPendingChanges()
    }

    @Test func unavailableVideoOptionsResolveTogetherAndEmptyCapabilitiesFail() {
        let capabilities = VideoCapabilities(configurations: [
            VideoConfiguration(resolution: .fullHD, frameRate: .fps30),
            VideoConfiguration(resolution: .ultraHD, frameRate: .fps24)
        ], codecs: [.h264], stabilizations: [.off], supportsTorch: false)
        var requested = VideoSettings.standard
        requested.resolution = .ultraHD
        requested.frameRate = .fps60
        requested.codec = .hevc
        requested.torch = true
        let resolved = capabilities.resolved(requested)
        #expect(resolved?.resolution == .ultraHD)
        #expect(resolved?.frameRate == .fps24)
        #expect(resolved?.codec == .h264)
        #expect(resolved?.stabilization == .off)
        #expect(resolved?.torch == false)
        #expect(VideoCapabilities().resolved(requested) == nil)
        #expect(requested.frameRate == .fps60)
    }

    @Test func legacyPresetRemainsPhotoAndRetainsMissingPhotoFields() throws {
        let legacy = Data(#"{"id":"10000000-0000-0000-0000-000000000001","name":"Legacy","settings":{"aspectRatio":"square","flashMode":"off"}}"#.utf8)
        let preset = try JSONDecoder().decode(CameraPreset.self, from: legacy)
        #expect(preset.captureMode == .photo)
        var current = CameraSettings.standard
        current.photoOutputFormat = .raw
        current.photoTimer = .fiveSeconds
        let applied = preset.settings.applying(to: current)
        #expect(applied.aspectRatio == .square)
        #expect(applied.photoOutputFormat == .raw)
        #expect(applied.photoTimer == .fiveSeconds)
        let video = CameraSettings.standard(for: .video)
        #expect(preset.settings.applying(to: video) == video)
    }

    @Test func fullVideoPresetSurvivesRepositoryRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("presets.json")
        var settings = CameraSettings.standard(for: .video)
        settings.video = VideoSettings(resolution: .ultraHD, frameRate: .fps25, codec: .hevc,
            stabilization: .cinematic, torch: true,
            microphone: .external(id: "usb.preset", name: "USB Mic"))
        settings.exposure = .manual(iso: 150, durationInSeconds: 1 / 50)
        let preset = CameraPreset(name: "Video", settings: CameraPresetSettings(settings: settings))
        try await JSONCameraPresetRepository(fileURL: url).save(preset)
        let restored = try await JSONCameraPresetRepository(fileURL: url).presets()
        #expect(restored == [preset])
        #expect(restored.first?.captureMode == .video)
        #expect(preset.settings.applying(to: .standard(for: .video)).video == settings.video)
    }

    @Test func unknownPresetFileVersionIsPreservedAndReported() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("presets.json")
        let data = Data(#"{"version":999,"presets":[]}"#.utf8)
        try data.write(to: url)
        let repository = JSONCameraPresetRepository(fileURL: url)
        await #expect(throws: (any Error).self) { try await repository.presets() }
        await #expect(throws: (any Error).self) { try await repository.replaceAll(with: []) }
        #expect(try Data(contentsOf: url) == data)
    }

    @Test @MainActor func selectionManualValuesAndOrderAreScopedToMode() {
        let photoA = CameraPreset(name: "Photo A", settings: CameraPresetSettings())
        let photoB = CameraPreset(name: "Photo B", settings: CameraPresetSettings())
        let video = CameraPreset(name: "Video", settings: CameraPresetSettings(captureMode: .video))
        let store = CameraPresetStore(presets: [photoA, video, photoB], repository: MemoryPresetRepository())
        store.select(id: photoA.id)
        store.activate(.video)
        #expect(store.modePresets == [video])
        #expect(store.selectedPresetID == nil)
        store.select(id: photoA.id)
        #expect(store.selectedPresetID == nil)
        store.select(id: video.id)
        store.activate(.photo)
        #expect(store.selectedPresetID == photoA.id)
        store.move(fromOffsets: IndexSet([0]), toOffset: 2)
        #expect(store.modePresets == [photoB, photoA])
        #expect(store.presets[1] == video)
        store.activate(.video)
        #expect(store.selectedPresetID == video.id)
        store.clearSelection()
        var settings = CameraSettings.standard(for: .video)
        settings.video.frameRate = .fps60
        store.updateUnselectedSettings(settings)
        #expect(store.unselectedSettings == settings)
        store.activate(.photo)
        #expect(store.unselectedSettings == .standard)
    }

    @Test @MainActor func quickPersonalizationPersistsPerModeWithoutCameraValues() throws {
        let suite = "VideoSettingsTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["focus", "photoTimer", "focus", "videoCodec"], forKey: "camera.quickSettings.v1")
        let store = QuickSettingsStore()
        let photo = UserDefaultsQuickSettingsRepository(defaults: defaults)
        let video = UserDefaultsQuickSettingsRepository(defaults: defaults, mode: .video)
        LoadQuickSettingsUseCase(store: store, repository: photo).execute()
        #expect(store.included == [.focus, .photoTimer])
        store.captureMode = .video
        LoadQuickSettingsUseCase(store: store, repository: video).execute()
        let customize = CustomizeQuickSettingsUseCase(store: store, repository: video)
        customize.execute(.add(.videoFrameRate))
        customize.execute(.add(.photoTimer))
        #expect(store.included == [.exposure, .focus, .whiteBalance, .videoFrameRate])
        store.captureMode = .photo
        #expect(store.included == [.focus, .photoTimer])
        let restored = QuickSettingsStore()
        restored.captureMode = .video
        LoadQuickSettingsUseCase(store: restored, repository: video).execute()
        #expect(restored.included == [.exposure, .focus, .whiteBalance, .videoFrameRate])
        #expect(defaults.data(forKey: "camera.settings.v1") == nil)
    }
}

private actor MemoryPresetRepository: CameraPresetRepository {
    private(set) var replacements = 0
    func presets() -> [CameraPreset] { [] }
    func save(_ preset: CameraPreset) {}
    func delete(id: UUID) {}
    func replaceAll(with presets: [CameraPreset]) { replacements += 1 }
}

@MainActor
private final class IgnoredCameraSettings: Throttling {
    func submit(_ value: CameraSettings) {}
    func submitImmediately(_ value: CameraSettings) {}
    func cancel() {}
}
