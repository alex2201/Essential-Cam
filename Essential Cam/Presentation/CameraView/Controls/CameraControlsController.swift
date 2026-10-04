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
            guard settings != oldValue else { return }
            guard !isDeviceApplicationSuppressed else { return }
            applySettings()
        }
    }

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
        settingsThrottler.cancel()
        zoomThrottler.cancel()
    }

    func synchronizeWithCamera(
        afterCameraSwitch: Bool = false,
        preferredZoomFactor: Double? = nil
    ) async {
        await updateExposureCapabilities()
        await updateFocusCapabilities()
        await updateWhiteBalanceCapabilities()
        await updateZoomCapabilities(preferredZoomFactor: preferredZoomFactor)
        await updateContentAwareCorrectionCapability()

        if afterCameraSwitch {
            settingsThrottler.cancel()
            zoomThrottler.cancel()
            do {
                try await cameraSession.applyAfterCameraSwitch(settings)
            } catch {
                // TODO: Track this error with the integrated logging service.
                cameraControlsLogger.error(
                    "Couldn't apply settings after camera switch: \(error.localizedDescription, privacy: .public)"
                )
            }
        } else {
            applySettingsImmediately()
        }
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
        let defaults = CameraSettings.standard
        var updatedSettings = settings
        updatedSettings.exposure = preset.exposure ?? defaults.exposure
        updatedSettings.focus = preset.focus ?? defaults.focus
        updatedSettings.whiteBalance = preset.whiteBalance ?? defaults.whiteBalance
        updatedSettings.aspectRatio = preset.aspectRatio ?? defaults.aspectRatio
        updatedSettings.flashMode = preset.flashMode ?? defaults.flashMode

        isDeviceApplicationSuppressed = true
        settings = updatedSettings
        cachePresetControlValues(from: updatedSettings)
        isDeviceApplicationSuppressed = false
        applySettingsImmediately()
    }

    func applyUnselectedSettings(_ unselectedSettings: CameraSettings) {
        var updatedSettings = settings
        updatedSettings.exposure = unselectedSettings.exposure
        updatedSettings.focus = unselectedSettings.focus
        updatedSettings.whiteBalance = unselectedSettings.whiteBalance
        updatedSettings.aspectRatio = unselectedSettings.aspectRatio
        updatedSettings.flashMode = unselectedSettings.flashMode

        isDeviceApplicationSuppressed = true
        settings = updatedSettings
        cachePresetControlValues(from: updatedSettings)
        isDeviceApplicationSuppressed = false
        applySettingsImmediately()
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

        Task {
            if let capabilities = await cameraSession.whiteBalanceCapabilities() {
                manualWhiteBalanceTemperature = supportedWhiteBalanceTemperature(
                    capabilities.currentTemperature
                )
                manualWhiteBalanceTint = supportedWhiteBalanceTint(capabilities.currentTint)
            }

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
        manualFocusLensPosition = capabilities.currentLensPosition

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
