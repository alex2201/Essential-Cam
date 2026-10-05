//
//  CameraControlsController.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

import Foundation
import OSLog

private let cameraControlsLogger = Logger(
    subsystem: "com.alexanderlopez.Essential-Cam",
    category: "camera.configuration"
)

@MainActor
@Observable
final class CameraControlsController {
    // MARK: - Settings

    private(set) var settings: CameraSettings {
        didSet {
            if settings.captureMode == .video, oldValue.captureMode == .video {
                microphoneHistory.rememberChange(from: oldValue.video.microphone, to: settings.video.microphone)
            }
            profiles[settings.captureMode] = settings
            guard settings != oldValue else { return }
            guard !isDeviceApplicationSuppressed else { return }
            applySettings()
        }
    }

    private var profiles = CaptureSettingsProfiles()
    private var microphoneHistory = VideoMicrophoneFallbackHistory()
    private var microphoneRefreshRevision = 0
    private(set) var isApplyingConfiguration = false
    private(set) var configurationNotice: String?
    private(set) var videoCapabilities = VideoCapabilities()

    var captureMode: CaptureMode { settings.captureMode }
    var availableVideoResolutions: [VideoResolution] {
        VideoResolution.allCases.filter { resolution in
            videoCapabilities.configurations.contains { $0.resolution == resolution }
        }
    }
    var availableVideoFrameRates: [VideoFrameRate] {
        VideoFrameRate.allCases.filter { fps in
            videoCapabilities.configurations.contains { $0.resolution == settings.video.resolution && $0.frameRate == fps }
        }
    }

    func switchCaptureMode(_ mode: CaptureMode) async {
        guard !isApplyingConfiguration, mode != captureMode else { return }
        cancelPendingChanges()
        isDeviceApplicationSuppressed = true
        settings = profiles[mode]
        cachePresetControlValues(from: settings)
        isDeviceApplicationSuppressed = false
        await synchronizeWithCamera(preferredZoomFactor: settings.zoomFactor)
    }

    func setVideoSettings(_ value: VideoSettings) {
        guard captureMode == .video, !isApplyingConfiguration else { return }
        isDeviceApplicationSuppressed = true
        settings.video = value
        isDeviceApplicationSuppressed = false
        Task { await synchronizeWithCamera(preferredZoomFactor: settings.zoomFactor) }
    }

    /// A structured task owned by the visible settings surface. Route notifications
    /// remain the fast path; polling also catches connections while audio is inactive.
    func monitorVideoMicrophones() async {
        while !Task.isCancelled {
            await refreshVideoMicrophones()
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
    }

    func refreshVideoMicrophones() async {
        microphoneRefreshRevision += 1
        let revision = microphoneRefreshRevision
        while isApplyingConfiguration {
            do { try await Task.sleep(for: .milliseconds(10)) } catch { return }
        }
        guard !Task.isCancelled else { return }
#if targetEnvironment(simulator)
        let inputs = [VideoMicrophone(id: "simulator.builtin", name: "iPhone Microphone", isBuiltIn: true)]
#else
        let inputs = await cameraSession.videoMicrophones()
#endif
        guard revision == microphoneRefreshRevision, !Task.isCancelled else { return }
        if isApplyingConfiguration {
            await refreshVideoMicrophones()
            return
        }
        await reconcileVideoMicrophones(inputs)
    }

    func reconcileVideoMicrophones(_ inputs: [VideoMicrophone]) async {
        // Avoid rebuilding an open picker when discovery finds the same inputs.
        if videoCapabilities.microphones != inputs {
            videoCapabilities.microphones = inputs
        }
        let selected = profiles[.video].video.microphone
        guard let fallback = microphoneHistory.fallback(for: selected, inputs: inputs) else { return }
        var effective = fallback
        var liveRouteFailed = false
        if captureMode == .video {
#if !targetEnvironment(simulator)
            do {
                guard let applied = try await cameraSession.applyMicrophoneFallback(from: selected, to: fallback) else { return }
                effective = applied
            } catch {
                effective = .automatic
                liveRouteFailed = true
                cameraControlsLogger.error("Couldn't restore audio input: \(error.localizedDescription, privacy: .public)")
            }
#endif
            guard !isApplyingConfiguration, captureMode == .video, settings.video.microphone == selected else { return }
            // Change only the audio choice. Never reconfigure the video format during recording.
            isDeviceApplicationSuppressed = true
            settings.video.microphone = effective
            isDeviceApplicationSuppressed = false
        } else {
            guard profiles[.video].video.microphone == selected else { return }
            microphoneHistory.rememberChange(from: selected, to: effective)
            profiles[.video].video.microphone = effective
        }
        configurationNotice = liveRouteFailed
            ? "The microphone disconnected. Automatic is selected for the next recording; the current recording couldn't switch audio. Stop recording and try again."
            : "The selected microphone is unavailable. Video now uses \(effective.displayName). Saved presets are unchanged."
    }

    func clearConfigurationNotice() { configurationNotice = nil }

    // MARK: - Capabilities

    private(set) var exposureBiasRange: ClosedRange<Double> = 0...0
    private(set) var exposureISORange: ClosedRange<Double> = 1...1
    private(set) var exposureDurationRange: ClosedRange<Double> = 1...1
    private(set) var supportsAutoFocus = false
    private(set) var supportsContinuousAutoFocus = false
    private(set) var supportsManualFocus = false
    private(set) var supportsAutomaticWhiteBalance = false
    private(set) var supportsManualWhiteBalance = false
    private(set) var zoomFactorRange: ClosedRange<Double> = 1...1
    private(set) var supportsContentAwareCorrection = false

    let whiteBalanceTemperatureRange: ClosedRange<Double> = 2_000...10_000
    let whiteBalanceTintRange: ClosedRange<Double> = -150...150

    var supportsAutomaticFocus: Bool {
        supportsContinuousAutoFocus || supportsAutoFocus
    }

    // MARK: - Dependencies

    private let cameraSession: CameraSession
    private let settingsThrottler: any Throttling<CameraSettings>
    private let zoomThrottler: any Throttling<CameraSettings>

    // MARK: - Cached Values

    private var isDeviceApplicationSuppressed = false
    private var profileRevision = 0
    private var automaticExposureBias: Float = 0
    private var manualExposureISO: Float = 1
    private var manualExposureDurationInSeconds: Double = 1
    private var manualFocusLensPosition: Float = 0.5
    private var manualWhiteBalanceTemperature: Float = 5_500
    private var manualWhiteBalanceTint: Float = 0

    // MARK: - Initialization

    init(
        cameraSession: CameraSession,
        settingsThrottler: (any Throttling<CameraSettings>)? = nil,
        zoomThrottler: (any Throttling<CameraSettings>)? = nil
    ) {
        self.cameraSession = cameraSession
        settings = .standard
        self.settingsThrottler = settingsThrottler
            ?? AsyncThrottler(interval: .milliseconds(100)) { settings in
                do {
                    try await cameraSession.apply(settings)
                } catch {
                    // TODO: Track this error with the integrated logging service.
                    cameraControlsLogger.error(
                        "Couldn't apply camera settings: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        self.zoomThrottler = zoomThrottler
            ?? AsyncThrottler(interval: .milliseconds(16)) { settings in
                do {
                    try await cameraSession.applyZoom(settings)
                } catch {
                    // TODO: Track this error with the integrated logging service.
                    cameraControlsLogger.error(
                        "Couldn't apply camera zoom: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
    }

    // MARK: - Camera Synchronization

    func cancelPendingChanges() {
        profileRevision += 1
        settingsThrottler.cancel()
        zoomThrottler.cancel()
    }

    func synchronizeWithCamera(
        afterCameraSwitch: Bool = false,
        preferredZoomFactor: Double? = nil
    ) async {
        guard !isApplyingConfiguration else { return }
        isApplyingConfiguration = true
        cancelPendingChanges()
        isDeviceApplicationSuppressed = true
        defer {
            isDeviceApplicationSuppressed = false
            isApplyingConfiguration = false
#if !targetEnvironment(simulator)
            if captureMode == .video { Task { await self.refreshVideoMicrophones() } }
#endif
        }
#if targetEnvironment(simulator)
        videoCapabilities = VideoCapabilities(
            configurations: VideoResolution.allCases.flatMap { resolution in
                VideoFrameRate.allCases.map { VideoConfiguration(resolution: resolution, frameRate: $0) }
            }, codecs: VideoCodec.allCases, stabilizations: VideoStabilization.allCases, supportsTorch: false
        )
        if captureMode == .video, let resolved = videoCapabilities.resolved(settings.video) {
            settings.video = resolved
        }
        videoCapabilities.microphones = [VideoMicrophone(id: "simulator.builtin", name: "iPhone Microphone", isBuiltIn: true)]
        manualExposureISO = 100
        manualExposureDurationInSeconds = 1 / 60
        cachePresetControlValues(from: settings)
        exposureBiasRange = -3...3
        exposureISORange = 25...2000
        exposureDurationRange = (1.0 / 8000)...(captureMode == .video ? 1 / Double(settings.video.frameRate.rawValue) : 1)
        supportsAutoFocus = true
        supportsContinuousAutoFocus = true
        supportsManualFocus = true
        supportsAutomaticWhiteBalance = true
        supportsManualWhiteBalance = true
        zoomFactorRange = 1...10
#else
        do {
            let requested = settings
            settings = try await cameraSession.prepare(requested)
            if settings.video != requested.video, captureMode == .video {
                configurationNotice = "Some video settings aren't supported by this camera. Compatible values are now selected; saved presets are unchanged."
            }
            if captureMode == .photo,
               settings.photoOutputFormat != requested.photoOutputFormat
                || settings.photoResolution != requested.photoResolution
                || settings.flashMode != requested.flashMode {
                configurationNotice = "Some photo settings aren't supported by this camera. Compatible values are now selected; saved presets are unchanged."
            }
            videoCapabilities = await cameraSession.videoCapabilities()
            await updateExposureCapabilities()
            await updateFocusCapabilities()
            await updateWhiteBalanceCapabilities()
            await updateZoomCapabilities(preferredZoomFactor: preferredZoomFactor ?? settings.zoomFactor)
            await updateContentAwareCorrectionCapability()
            cachePresetControlValues(from: settings)
            try await cameraSession.apply(settings)
        } catch {
            settings = await cameraSession.configuredProfileSettings()
            configurationNotice = "Couldn't apply this camera configuration. The previous settings were restored."
            cameraControlsLogger.error("Couldn't configure capture profile: \(error.localizedDescription, privacy: .public)")
        }
#endif
    }

    // MARK: - Capture Configuration

    func setAspectRatio(_ aspectRatio: CameraAspectRatio) {
        isDeviceApplicationSuppressed = true
        settings.aspectRatio = aspectRatio
        isDeviceApplicationSuppressed = false
    }

    func setFlashMode(_ flashMode: CameraFlashMode) {
        isDeviceApplicationSuppressed = true
        settings.flashMode = flashMode
        isDeviceApplicationSuppressed = false
    }

    func setPhotoOutputFormat(_ outputFormat: PhotoOutputFormat) {
        isDeviceApplicationSuppressed = true
        settings.photoOutputFormat = outputFormat
        isDeviceApplicationSuppressed = false
    }

    func setPhotoResolution(_ resolution: PhotoResolution?) {
        isDeviceApplicationSuppressed = true
        settings.photoResolution = resolution
        isDeviceApplicationSuppressed = false
    }

    func setPhotoTimer(_ timer: PhotoTimer) {
        isDeviceApplicationSuppressed = true
        settings.photoTimer = timer
        isDeviceApplicationSuppressed = false
    }

    func setContentAwareCorrection(_ correction: ContentAwareCorrection) {
        guard correction == .off || supportsContentAwareCorrection else { return }
        isDeviceApplicationSuppressed = true
        settings.contentAwareCorrection = correction
        isDeviceApplicationSuppressed = false
    }

    func applyPreset(_ preset: CameraPresetSettings) {
        guard preset.captureMode == captureMode, !isApplyingConfiguration else { return }
        isDeviceApplicationSuppressed = true
        settings = preset.applying(to: settings)
        cachePresetControlValues(from: settings)
        isDeviceApplicationSuppressed = false
        Task { await synchronizeWithCamera(preferredZoomFactor: settings.zoomFactor) }
    }

    func applyUnselectedSettings(_ unselectedSettings: CameraSettings) {
        guard unselectedSettings.captureMode == captureMode, !isApplyingConfiguration else { return }
        isDeviceApplicationSuppressed = true
        settings = unselectedSettings
        cachePresetControlValues(from: settings)
        isDeviceApplicationSuppressed = false
        Task { await synchronizeWithCamera(preferredZoomFactor: settings.zoomFactor) }
    }

    // MARK: - Zoom

    func setZoomFactor(_ zoomFactor: Double) {
        let supportedZoomFactor = min(
            max(zoomFactor, zoomFactorRange.lowerBound),
            zoomFactorRange.upperBound
        )

        isDeviceApplicationSuppressed = true
        settings.zoomFactor = supportedZoomFactor
        isDeviceApplicationSuppressed = false
        zoomThrottler.submit(settings)
    }

    // MARK: - Exposure

    func useAutomaticExposure() {
        settings.exposure = .automatic(exposureBias: automaticExposureBias)
    }

    func useManualExposure() {
        settings.exposure = .manual(
            iso: manualExposureISO,
            durationInSeconds: manualExposureDurationInSeconds
        )
    }

    func setExposureBias(_ exposureBias: Float) {
        automaticExposureBias = exposureBias
        settings.exposure = .automatic(exposureBias: exposureBias)
    }

    func setManualExposureISO(_ iso: Float) {
        manualExposureISO = iso
        settings.exposure = .manual(
            iso: iso,
            durationInSeconds: manualExposureDurationInSeconds
        )
    }

    func setManualExposureDuration(_ durationInSeconds: Double) {
        manualExposureDurationInSeconds = durationInSeconds
        settings.exposure = .manual(
            iso: manualExposureISO,
            durationInSeconds: durationInSeconds
        )
    }

    // MARK: - Focus

    func useAutomaticFocus() {
        if supportsContinuousAutoFocus {
            settings.focus = .continuousAuto
        } else if supportsAutoFocus {
            settings.focus = .auto
        }
    }

    func useManualFocus() {
        guard supportsManualFocus else { return }
        settings.focus = .manual(lensPosition: manualFocusLensPosition)
    }

    func setManualFocusLensPosition(_ lensPosition: Float) {
        guard supportsManualFocus else { return }
        let supportedPosition = min(max(lensPosition, 0), 1)
        manualFocusLensPosition = supportedPosition
        settings.focus = .manual(lensPosition: supportedPosition)
    }

    // MARK: - White Balance

    func useAutomaticWhiteBalance() {
        guard supportsAutomaticWhiteBalance else { return }
        settings.whiteBalance = .continuousAuto
    }

    func useManualWhiteBalance() {
        guard supportsManualWhiteBalance else { return }

        let mode = captureMode
        let revision = profileRevision
        let previousBalance = settings.whiteBalance
        Task {
            if let capabilities = await cameraSession.whiteBalanceCapabilities() {
                guard mode == captureMode, revision == profileRevision, settings.whiteBalance == previousBalance,
                      !isApplyingConfiguration else { return }
                manualWhiteBalanceTemperature = supportedWhiteBalanceTemperature(
                    capabilities.currentTemperature
                )
                manualWhiteBalanceTint = supportedWhiteBalanceTint(capabilities.currentTint)
            }

            guard mode == captureMode, revision == profileRevision, settings.whiteBalance == previousBalance,
                  !isApplyingConfiguration else { return }
            settings.whiteBalance = .manual(
                temperature: manualWhiteBalanceTemperature,
                tint: manualWhiteBalanceTint
            )
        }
    }

    func setManualWhiteBalanceTemperature(_ temperature: Float) {
        guard supportsManualWhiteBalance else { return }
        manualWhiteBalanceTemperature = supportedWhiteBalanceTemperature(temperature)
        settings.whiteBalance = .manual(
            temperature: manualWhiteBalanceTemperature,
            tint: manualWhiteBalanceTint
        )
    }

    func setManualWhiteBalanceTint(_ tint: Float) {
        guard supportsManualWhiteBalance else { return }
        manualWhiteBalanceTint = supportedWhiteBalanceTint(tint)
        settings.whiteBalance = .manual(
            temperature: manualWhiteBalanceTemperature,
            tint: manualWhiteBalanceTint
        )
    }

    // MARK: - Settings Application

    private func applySettings() {
        settingsThrottler.submit(settings)
    }

    private func applySettingsImmediately() {
        settingsThrottler.submitImmediately(settings)
    }

    private func cachePresetControlValues(from settings: CameraSettings) {
        switch settings.exposure {
        case let .automatic(exposureBias):
            automaticExposureBias = exposureBias
        case let .manual(iso, durationInSeconds):
            manualExposureISO = iso
            manualExposureDurationInSeconds = durationInSeconds
        }

        if case let .manual(lensPosition) = settings.focus {
            manualFocusLensPosition = lensPosition
        }

        if case let .manual(temperature, tint) = settings.whiteBalance {
            manualWhiteBalanceTemperature = temperature
            manualWhiteBalanceTint = tint
        }
    }

    // MARK: - Capability Updates

    private func updateExposureCapabilities() async {
        guard let capabilities = await cameraSession.exposureCapabilities() else { return }

        exposureBiasRange = Double(capabilities.exposureBiasRange.lowerBound)...Double(capabilities.exposureBiasRange.upperBound)
        exposureISORange = Double(capabilities.isoRange.lowerBound)...Double(capabilities.isoRange.upperBound)
        exposureDurationRange = capabilities.durationRange
        manualExposureISO = capabilities.currentISO
        manualExposureDurationInSeconds = capabilities.currentDurationInSeconds

        switch settings.exposure {
        case let .automatic(exposureBias):
            let supportedBias = min(
                max(exposureBias, capabilities.exposureBiasRange.lowerBound),
                capabilities.exposureBiasRange.upperBound
            )
            automaticExposureBias = supportedBias
            if supportedBias != exposureBias {
                settings.exposure = .automatic(exposureBias: supportedBias)
            }
        case let .manual(iso, durationInSeconds):
            let supportedISO = min(
                max(iso, capabilities.isoRange.lowerBound),
                capabilities.isoRange.upperBound
            )
            let supportedDuration = min(
                max(durationInSeconds, capabilities.durationRange.lowerBound),
                capabilities.durationRange.upperBound
            )
            manualExposureISO = supportedISO
            manualExposureDurationInSeconds = supportedDuration
            if supportedISO != iso || supportedDuration != durationInSeconds {
                settings.exposure = .manual(
                    iso: supportedISO,
                    durationInSeconds: supportedDuration
                )
            }
        }
    }

    private func updateFocusCapabilities() async {
        guard let capabilities = await cameraSession.focusCapabilities() else {
            supportsAutoFocus = false
            supportsContinuousAutoFocus = false
            supportsManualFocus = false
            return
        }

        supportsAutoFocus = capabilities.supportsAutoFocus
        supportsContinuousAutoFocus = capabilities.supportsContinuousAutoFocus
        supportsManualFocus = capabilities.supportsManualFocus
        if case let .manual(position) = settings.focus {
            manualFocusLensPosition = position
        } else { manualFocusLensPosition = capabilities.currentLensPosition }

        switch settings.focus {
        case .manual where !supportsManualFocus:
            useAutomaticFocus()
        case .auto where !supportsAutoFocus:
            useAutomaticFocus()
        case .continuousAuto where !supportsContinuousAutoFocus:
            useAutomaticFocus()
        case .locked:
            useAutomaticFocus()
        default:
            break
        }
    }

    private func updateWhiteBalanceCapabilities() async {
        guard let capabilities = await cameraSession.whiteBalanceCapabilities() else {
            supportsAutomaticWhiteBalance = false
            supportsManualWhiteBalance = false
            return
        }

        supportsAutomaticWhiteBalance = capabilities.supportsContinuousAutoWhiteBalance
        supportsManualWhiteBalance = capabilities.supportsLockedWhiteBalance
        manualWhiteBalanceTemperature = supportedWhiteBalanceTemperature(
            capabilities.currentTemperature
        )
        manualWhiteBalanceTint = supportedWhiteBalanceTint(capabilities.currentTint)

        switch settings.whiteBalance {
        case .manual where !supportsManualWhiteBalance:
            useAutomaticWhiteBalance()
        case .auto, .locked:
            useAutomaticWhiteBalance()
        case .continuousAuto where !supportsAutomaticWhiteBalance:
            break
        case let .manual(temperature, tint):
            let supportedTemperature = supportedWhiteBalanceTemperature(temperature)
            let supportedTint = supportedWhiteBalanceTint(tint)
            manualWhiteBalanceTemperature = supportedTemperature
            manualWhiteBalanceTint = supportedTint
            if supportedTemperature != temperature || supportedTint != tint {
                settings.whiteBalance = .manual(
                    temperature: supportedTemperature,
                    tint: supportedTint
                )
            }
        default:
            break
        }
    }

    private func updateZoomCapabilities(preferredZoomFactor: Double? = nil) async {
        guard let capabilities = await cameraSession.zoomCapabilities() else {
            zoomFactorRange = 1...1
            return
        }

        zoomFactorRange = capabilities.range
        let zoomFactor = preferredZoomFactor.map {
            min(max($0, capabilities.range.lowerBound), capabilities.range.upperBound)
        } ?? capabilities.currentZoomFactor

        isDeviceApplicationSuppressed = true
        settings.zoomFactor = zoomFactor
        isDeviceApplicationSuppressed = false
    }

    private func updateContentAwareCorrectionCapability() async {
        supportsContentAwareCorrection = await cameraSession.supportsContentAwareCorrection()
        if !supportsContentAwareCorrection, settings.contentAwareCorrection != .off {
            setContentAwareCorrection(.off)
        }
    }

    // MARK: - White Balance Validation

    private func supportedWhiteBalanceTemperature(_ temperature: Float) -> Float {
        min(
            max(temperature, Float(whiteBalanceTemperatureRange.lowerBound)),
            Float(whiteBalanceTemperatureRange.upperBound)
        )
    }

    private func supportedWhiteBalanceTint(_ tint: Float) -> Float {
        min(
            max(tint, Float(whiteBalanceTintRange.lowerBound)),
            Float(whiteBalanceTintRange.upperBound)
        )
    }
}
