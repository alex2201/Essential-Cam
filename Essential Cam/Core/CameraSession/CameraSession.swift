//
//  CameraSession.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

@preconcurrency import AVFoundation
import Foundation

struct CameraExposureCapabilities: Sendable {
    let exposureBiasRange: ClosedRange<Float>
    let isoRange: ClosedRange<Float>
    let durationRange: ClosedRange<Double>
    let currentISO: Float
    let currentDurationInSeconds: Double
}

struct CameraFocusCapabilities: Sendable {
    let supportsAutoFocus: Bool
    let supportsContinuousAutoFocus: Bool
    let supportsManualFocus: Bool
    let currentLensPosition: Float
}

struct CameraWhiteBalanceCapabilities: Sendable {
    let supportsContinuousAutoWhiteBalance: Bool
    let supportsLockedWhiteBalance: Bool
    let currentTemperature: Float
    let currentTint: Float
}

struct CameraZoomCapabilities: Sendable {
    let range: ClosedRange<Double>
    let currentZoomFactor: Double
}

actor CameraSession {
    nonisolated let captureSession: AVCaptureSession
    nonisolated let events: AsyncStream<CameraSessionEvent>

    private let sessionQueue = DispatchSerialQueue(
        label: "com.alexanderlopez.Essential-Cam.capture-session"
    )
    private let deviceLookup: any CameraDeviceLookup
    private let photoCaptureService: any PhotoCaptureService
    private let videoCaptureService: any VideoCaptureService
    private let photoWideColorConfiguration: Bool
    private nonisolated let eventMonitor: CameraSessionEventMonitor
    
    private var activeVideoInput: AVCaptureDeviceInput?
    private var isSetUp = false
    private var configuredSettings = CameraSettings.standard
    private var isCapturingPhoto = false
    private var isRecordingVideo = false
    private var isStoppingVideo = false
    private var recordingID: UUID?
    private var activeAudioInput: AVCaptureDeviceInput?
    private var manuallyActivatedAudio = false
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var selectedCameraPosition = Camera.Position.back

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        sessionQueue.asUnownedSerialExecutor()
    }

    init(
        captureSession: AVCaptureSession = .init(),
        deviceLookup: any CameraDeviceLookup = DefaultCameraDeviceLookup(),
        photoCaptureService: any PhotoCaptureService = DefaultPhotoCaptureService(),
        videoCaptureService: any VideoCaptureService = DefaultVideoCaptureService()
    ) {
        self.captureSession = captureSession
        let eventMonitor = CameraSessionEventMonitor(session: captureSession)
        self.eventMonitor = eventMonitor
        events = eventMonitor.events
        self.deviceLookup = deviceLookup
        self.photoCaptureService = photoCaptureService
        self.videoCaptureService = videoCaptureService
        photoWideColorConfiguration = captureSession.automaticallyConfiguresCaptureDeviceForWideColor
    }

    func start() async throws(CameraSessionError) {
        try await checkCaptureAuthorizationStatus()

        guard !captureSession.isRunning else { return }

        try setUp()
        captureSession.startRunning()
    }

    func stop() {
        guard captureSession.isRunning, !isRecordingVideo else { return }
        captureSession.stopRunning()
    }

    func snapshot() -> CameraSessionSnapshot {
        CameraSessionSnapshot(
            isConfigured: isSetUp,
            isRunning: captureSession.isRunning,
            isInterrupted: captureSession.isInterrupted,
            selectedCamera: selectedCamera()
        )
    }

    func availableCameras() -> [Camera] {
        selectedCameraDevices.compactMap {
            $0.toDomainModel(displayZoomFactor: deviceLookup.displayZoomFactor(for: $0))
        }
    }

    func availableVirtualCameras() -> [Camera] {
        selectedVirtualCameraDevices.compactMap {
            $0.toDomainModel()
        }
    }

    func selectedCamera() -> Camera? {
        guard let device = activeVideoInput?.device else { return nil }
        return device.toDomainModel(
            displayZoomFactor: deviceLookup.displayZoomFactor(for: device)
        )
    }

    func canSwitchCameraPosition() -> Bool {
        deviceLookup.mainFrontCamera != nil && deviceLookup.mainBackCamera != nil
    }

    func availablePhotoOutputFormats() -> [PhotoOutputFormat] {
        photoCaptureService.availablePhotoOutputFormats()
    }

    func availablePhotoResolutions() -> [PhotoResolution] {
        let resolutions = selectedCameraDevices.compactMap { device in
            device.formats
                .flatMap(\.supportedMaxPhotoDimensions)
                .map { PhotoResolution(width: $0.width, height: $0.height) }
                .max { $0.megapixels < $1.megapixels }
        }

        return Array(Set(resolutions)).sorted { $0.megapixels < $1.megapixels }
    }

    func supportsContentAwareCorrection() -> Bool {
        photoCaptureService.supportsContentAwareCorrection()
    }

    func exposureCapabilities() -> CameraExposureCapabilities? {
        guard let device = activeVideoInput?.device else { return nil }

        return CameraExposureCapabilities(
            exposureBiasRange: device.minExposureTargetBias...device.maxExposureTargetBias,
            isoRange: device.activeFormat.minISO...device.activeFormat.maxISO,
            durationRange: device.activeFormat.minExposureDuration.seconds...max(
                device.activeFormat.minExposureDuration.seconds,
                configuredSettings.captureMode == .video
                    ? min(device.activeFormat.maxExposureDuration.seconds, 1 / Double(configuredSettings.video.frameRate.rawValue))
                    : device.activeFormat.maxExposureDuration.seconds
            ),
            currentISO: device.iso,
            currentDurationInSeconds: device.exposureDuration.seconds
        )
    }

    func focusCapabilities() -> CameraFocusCapabilities? {
        guard let device = activeVideoInput?.device else { return nil }

        return CameraFocusCapabilities(
            supportsAutoFocus: device.isFocusModeSupported(.autoFocus),
            supportsContinuousAutoFocus: device.isFocusModeSupported(.continuousAutoFocus),
            supportsManualFocus: device.isLockingFocusWithCustomLensPositionSupported,
            currentLensPosition: device.lensPosition
        )
    }

    func whiteBalanceCapabilities() -> CameraWhiteBalanceCapabilities? {
        guard !captureSession.isInterrupted,
              let device = activeVideoInput?.device,
              let gains = device.deviceWhiteBalanceGains.clamped(maximumGain: device.maxWhiteBalanceGain) else {
            return nil
        }

        let currentValues = device.temperatureAndTintValues(for: gains)

        return CameraWhiteBalanceCapabilities(
            supportsContinuousAutoWhiteBalance: device.isWhiteBalanceModeSupported(
                .continuousAutoWhiteBalance
            ),
            supportsLockedWhiteBalance: device.isWhiteBalanceModeSupported(.locked),
            currentTemperature: currentValues.temperature,
            currentTint: currentValues.tint
        )
    }

    func zoomCapabilities() -> CameraZoomCapabilities? {
        guard let device = activeVideoInput?.device else { return nil }

        let displayMultiplier = Double(displayZoomFactorMultiplier(for: device))

        return CameraZoomCapabilities(
            range: Double(device.minAvailableVideoZoomFactor) * displayMultiplier
                ... Double(device.maxAvailableVideoZoomFactor) * displayMultiplier,
            currentZoomFactor: Double(device.videoZoomFactor) * displayMultiplier
        )
    }

    func configuredProfileSettings() -> CameraSettings { configuredSettings }

    func applyMicrophoneFallback(from previous: VideoMicrophoneSelection,
                                 to fallback: VideoMicrophoneSelection) throws -> VideoMicrophoneSelection? {
        guard configuredSettings.captureMode == .video,
              configuredSettings.video.microphone == previous else { return nil }
        var effective = fallback.isUnavailable(in: videoMicrophones()) ? .automatic : fallback
        if isRecordingVideo {
            do {
                effective = try VideoMicrophoneRouter.changeInputWhileRecording(
                    effective, cameraPosition: activeVideoInput?.device.position ?? .unspecified,
                    captureSession: captureSession
                )
            } catch {
                // A second input can disappear between discovery and route selection.
                effective = try VideoMicrophoneRouter.changeInputWhileRecording(
                    .automatic, cameraPosition: .unspecified, captureSession: captureSession
                )
            }
        }
        configuredSettings.video.microphone = effective
        return effective
    }

    func videoMicrophones() -> [VideoMicrophone] {
        VideoMicrophoneRouter.availableMicrophones()
    }

    func videoCapabilities() -> VideoCapabilities {
        guard let device = activeVideoInput?.device else { return VideoCapabilities() }
        let configurations = VideoResolution.allCases.flatMap { resolution in
            VideoFrameRate.allCases.compactMap { fps -> VideoConfiguration? in
                guard videoFormat(device: device, resolution: resolution, frameRate: fps) != nil else { return nil }
                return VideoConfiguration(resolution: resolution, frameRate: fps)
            }
        }
        return VideoCapabilities(
            configurations: configurations,
            codecs: videoCaptureService.availableCodecs,
            stabilizations: VideoStabilization.allCases.filter {
                $0 == .off || (videoCaptureService.output.connection(with: .video)?.isVideoStabilizationSupported == true
                    && device.activeFormat.isVideoStabilizationModeSupported($0.avFoundationValue))
            },
            // Availability can transiently become false during a session transaction.
            // Advertise capability; setTorchModeOn reports runtime/thermal failures.
            supportsTorch: device.hasTorch && device.isTorchModeSupported(.on),
            microphones: videoMicrophones()
        )
    }

    private func videoFormat(
        device: AVCaptureDevice, resolution: VideoResolution, frameRate: VideoFrameRate
    ) -> AVCaptureDevice.Format? {
        device.formats.first { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dimensions.width == resolution.width && dimensions.height == resolution.height
                && format.videoSupportedFrameRateRanges.contains {
                    $0.minFrameRate <= Double(frameRate.rawValue) && $0.maxFrameRate >= Double(frameRate.rawValue)
                } && format.supportedColorSpaces.contains(.sRGB)
        }
    }

    /// A synchronous transaction on the camera executor. Roll back before reporting failure.
    func prepare(_ requested: CameraSettings) throws(CameraSessionError) -> CameraSettings {
        guard !Task.isCancelled, !isCapturingPhoto, !isRecordingVideo else { throw .operationInProgress }
        guard isSetUp, let device = activeVideoInput?.device else { throw .setupFailed }
        let previous = configuredSettings
        let previousFormat = device.activeFormat
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        do {
            try device.lockForConfiguration()
        } catch { throw .configurationFailed }
        defer { device.unlockForConfiguration() }
        do {
            let result = try configure(requested, device: device)
            configuredSettings = result
            apply(result.exposure, to: device)
            apply(result.focus, to: device)
            apply(result.whiteBalance, to: device)
            apply(result.avFoundationZoomFactor, to: device)
            return result
        } catch {
            device.activeFormat = previousFormat
            _ = try? configure(previous, device: device)
            configuredSettings = previous
            apply(previous.exposure, to: device)
            apply(previous.focus, to: device)
            apply(previous.whiteBalance, to: device)
            apply(previous.avFoundationZoomFactor, to: device)
            throw .configurationFailed
        }
    }

    private func configure(_ requested: CameraSettings, device: AVCaptureDevice) throws -> CameraSettings {
        var result = requested
        if requested.captureMode == .photo {
            captureSession.automaticallyConfiguresCaptureDeviceForWideColor = photoWideColorConfiguration
            if device.hasTorch { device.torchMode = .off }
            if captureSession.outputs.contains(videoCaptureService.output) {
                captureSession.removeOutput(videoCaptureService.output)
            }
            guard captureSession.canSetSessionPreset(.photo) else { throw CameraSessionError.configurationFailed }
            captureSession.sessionPreset = .photo
            if !captureSession.outputs.contains(photoCaptureService.output) {
                try addOutput(photoCaptureService.output)
            }
            photoCaptureService.updateConfiguration(for: device)
            let formats = photoCaptureService.availablePhotoOutputFormats()
            if !formats.contains(result.photoOutputFormat), let fallback = formats.first {
                result.photoOutputFormat = fallback
            }
            let resolutions = photoCaptureService.availablePhotoResolutions()
            if let requestedResolution = result.photoResolution, !resolutions.contains(requestedResolution) {
                result.photoResolution = resolutions.last
            }
            if !photoCaptureService.supportsFlashMode(result.flashMode) { result.flashMode = .off }
            return result
        }
        guard captureSession.canSetSessionPreset(.inputPriority) else { throw CameraSessionError.configurationFailed }
        captureSession.automaticallyConfiguresCaptureDeviceForWideColor = false
        captureSession.sessionPreset = .inputPriority
        if captureSession.outputs.contains(photoCaptureService.output) {
            captureSession.removeOutput(photoCaptureService.output)
        }
        // Resolve dimension/fps before attaching the movie output to the new format.
        var capabilities = videoCapabilities()
        capabilities.codecs = VideoCodec.allCases
        guard let candidate = capabilities.resolved(requested.video),
              let format = videoFormat(device: device, resolution: candidate.resolution, frameRate: candidate.frameRate) else {
            throw VideoCaptureError.unsupportedConfiguration
        }
        if device.activeFormat !== format { device.activeFormat = format }
        if !captureSession.outputs.contains(videoCaptureService.output) {
            try addOutput(videoCaptureService.output)
        }
        let duration = CMTime(value: 1, timescale: candidate.frameRate.rawValue)
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        device.automaticallyAdjustsVideoHDREnabled = false
        if format.isVideoHDRSupported { device.isVideoHDREnabled = false }
        device.activeColorSpace = .sRGB
        capabilities = videoCapabilities()
        var selected = requested.video
        selected.resolution = candidate.resolution
        selected.frameRate = candidate.frameRate
        guard let resolved = capabilities.resolved(selected) else { throw VideoCaptureError.unsupportedConfiguration }
        result.video = resolved
        try videoCaptureService.configure(resolved)
        if device.hasTorch {
            if resolved.torch && device.isTorchModeSupported(.on) {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else { device.torchMode = .off }
        }
        return result
    }

    func apply(_ settings: CameraSettings) throws(CameraSessionError) {
        guard !Task.isCancelled, settings.captureMode == configuredSettings.captureMode,
              settings.captureMode != .video || settings.video == configuredSettings.video else { return }
        guard !isCapturingPhoto, !isRecordingVideo else { throw .operationInProgress }
        guard isSetUp, let device = activeVideoInput?.device else {
            throw .setupFailed
        }

        do {
            try device.lockForConfiguration()
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw .configurationFailed
        }

        defer { device.unlockForConfiguration() }

        apply(settings.exposure, to: device)
        apply(settings.focus, to: device)
        apply(settings.whiteBalance, to: device)
        apply(settings.avFoundationZoomFactor, to: device)
        configuredSettings = settings
    }

    func applyZoom(_ settings: CameraSettings) throws(CameraSessionError) {
        guard !Task.isCancelled, settings.captureMode == configuredSettings.captureMode,
              settings.captureMode != .video || settings.video == configuredSettings.video else { return }
        guard !isCapturingPhoto, !isRecordingVideo else { throw .operationInProgress }
        guard isSetUp, let device = activeVideoInput?.device else {
            throw .setupFailed
        }

        do {
            try device.lockForConfiguration()
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw .configurationFailed
        }

        defer { device.unlockForConfiguration() }

        if case .automatic = settings.exposure {
            apply(settings.exposure, to: device)
        }

        switch settings.focus {
        case .auto, .continuousAuto:
            apply(settings.focus, to: device)
        case .locked, .manual:
            break
        }

        switch settings.whiteBalance {
        case .auto, .continuousAuto:
            apply(settings.whiteBalance, to: device)
        case .locked, .manual:
            break
        }

        apply(settings.avFoundationZoomFactor, to: device)
    }

    func applyAfterCameraSwitch(
        _ settings: CameraSettings
    ) throws(CameraSessionError) {
        guard !Task.isCancelled, settings.captureMode == configuredSettings.captureMode,
              settings.captureMode != .video || settings.video == configuredSettings.video else { return }
        guard !isCapturingPhoto, !isRecordingVideo else { throw .operationInProgress }
        guard isSetUp, let device = activeVideoInput?.device else {
            throw .setupFailed
        }

        do {
            try device.lockForConfiguration()
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw .configurationFailed
        }

        defer { device.unlockForConfiguration() }

        applyAfterCameraSwitch(settings.exposure, to: device)
        applyAfterCameraSwitch(settings.focus, to: device)
        applyAfterCameraSwitch(settings.whiteBalance, to: device)
        apply(settings.avFoundationZoomFactor, to: device)
    }

    func selectCamera(id: Camera.ID) throws(CameraSessionError) {
        guard !isCapturingPhoto, !isRecordingVideo else { throw .operationInProgress }
        guard isSetUp else {
            throw .setupFailed
        }

        let selectableDevices = selectedCameraDevices + selectedVirtualCameraDevices
        guard let device = selectableDevices.first(where: { $0.uniqueID == id }) else {
            throw .cameraNotFound
        }

        try replaceVideoInput(with: device)
    }

    func toggleCameraPosition() throws(CameraSessionError) {
        guard !isCapturingPhoto, !isRecordingVideo else { throw .operationInProgress }
        guard isSetUp else {
            throw .setupFailed
        }

        let newPosition: Camera.Position = selectedCameraPosition == .back ? .front : .back
        let device: AVCaptureDevice?

        switch newPosition {
        case .front:
            device = deviceLookup.mainFrontCamera
        case .back:
            device = deviceLookup.mainBackCamera
        }

        guard let device else {
            throw .cameraNotFound
        }

        try replaceVideoInput(with: device)
        selectedCameraPosition = newPosition
    }

    private func setUp() throws(CameraSessionError) {
        guard !isSetUp else { return }

        guard let defaultCamera = getDefaultCamera() else {
            throw .setupFailed
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if #available(iOS 26.0, *) {
            captureSession.configuresApplicationAudioSessionForBluetoothHighQualityRecording = true
        }

        activeVideoInput = try addInput(for: defaultCamera)
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: defaultCamera, previewLayer: nil)
        captureSession.sessionPreset = .photo

        for capture in captureComponents {
            try addOutput(capture.output)
            capture.updateConfiguration(for: defaultCamera)
        }

        isSetUp = true
    }
    
    private func getDefaultCamera() -> AVCaptureDevice? {
        switch selectedCameraPosition {
        case .front:
            return deviceLookup.mainFrontCamera
        case .back:
            return deviceLookup.mainBackCamera
        }
    }

    private func replaceVideoInput(
        with device: AVCaptureDevice
    ) throws(CameraSessionError) {
        guard activeVideoInput?.device.uniqueID != device.uniqueID else { return }

        let newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: device)
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw .addInputFailed
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        let previousInput = activeVideoInput
        if let previousInput {
            captureSession.removeInput(previousInput)
        }

        guard captureSession.canAddInput(newInput) else {
            if let previousInput, captureSession.canAddInput(previousInput) {
                captureSession.addInput(previousInput)
            }
            throw .addInputFailed
        }

        captureSession.addInput(newInput)
        activeVideoInput = newInput
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)

        if configuredSettings.captureMode == .photo {
            for capture in captureComponents { capture.updateConfiguration(for: device) }
        }
    }

    private var selectedCameraDevices: [AVCaptureDevice] {
        switch selectedCameraPosition {
        case .front:
            return deviceLookup.frontCameras
        case .back:
            return deviceLookup.backCameras
        }
    }

    private var selectedVirtualCameraDevices: [AVCaptureDevice] {
        switch selectedCameraPosition {
        case .front:
            return []
        case .back:
            return deviceLookup.virtualBackCameras
        }
    }

    private var captureComponents: [any CameraCaptureComponent] {
        [photoCaptureService]
    }

    private func apply(
        _ exposure: ExposureSetting,
        to device: AVCaptureDevice
    ) {
        switch exposure.avFoundationConfiguration {
        case let .mode(mode, exposureBias):
            guard device.isExposureModeSupported(mode) else { return }

            device.exposureMode = mode

            if let exposureBias {
                let supportedBias = min(
                    max(exposureBias, device.minExposureTargetBias),
                    device.maxExposureTargetBias
                )
                device.setExposureTargetBias(supportedBias)
            }
        case let .manual(iso, duration):
            guard device.isExposureModeSupported(.custom) else { return }

            let supportedISO = min(
                max(iso, device.activeFormat.minISO),
                device.activeFormat.maxISO
            )
            let supportedDurationInSeconds = min(
                max(
                    duration.seconds,
                    device.activeFormat.minExposureDuration.seconds
                ),
                configuredSettings.captureMode == .video
                    ? min(device.activeFormat.maxExposureDuration.seconds, 1 / Double(configuredSettings.video.frameRate.rawValue))
                    : device.activeFormat.maxExposureDuration.seconds
            )
            let supportedDuration = CMTime(
                seconds: supportedDurationInSeconds,
                preferredTimescale: duration.timescale
            )

            device.setExposureModeCustom(
                duration: supportedDuration,
                iso: supportedISO
            )
        }
    }

    private func applyAfterCameraSwitch(
        _ exposure: ExposureSetting,
        to device: AVCaptureDevice
    ) {
        guard case let .automatic(exposureBias) = exposure else {
            apply(exposure, to: device)
            return
        }

        let mode: AVCaptureDevice.ExposureMode = device.isExposureModeSupported(.autoExpose)
            ? .autoExpose
            : .continuousAutoExposure
        device.exposureMode = mode

        let supportedBias = min(
            max(exposureBias, device.minExposureTargetBias),
            device.maxExposureTargetBias
        )
        device.setExposureTargetBias(supportedBias)
    }

    private func apply(
        _ focus: FocusSetting,
        to device: AVCaptureDevice
    ) {
        switch focus.avFoundationConfiguration {
        case let .mode(mode):
            guard device.isFocusModeSupported(mode) else { return }
            device.focusMode = mode
        case let .manual(lensPosition):
            guard device.isLockingFocusWithCustomLensPositionSupported else {
                return
            }
            device.setFocusModeLocked(
                lensPosition: min(max(lensPosition, 0), 1)
            )
        }
    }

    private func applyAfterCameraSwitch(
        _ focus: FocusSetting,
        to device: AVCaptureDevice
    ) {
        switch focus {
        case .auto, .continuousAuto:
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            } else {
                apply(focus, to: device)
            }
        case .locked, .manual:
            apply(focus, to: device)
        }
    }

    private func apply(
        _ whiteBalance: WhiteBalanceSetting,
        to device: AVCaptureDevice
    ) {
        switch whiteBalance.avFoundationConfiguration {
        case let .mode(mode):
            guard device.isWhiteBalanceModeSupported(mode) else { return }
            device.whiteBalanceMode = mode
        case let .manual(temperatureAndTint):
            guard device.isWhiteBalanceModeSupported(.locked) else { return }

            let gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
            let supportedGains = AVCaptureDevice.WhiteBalanceGains(
                redGain: min(max(gains.redGain, 1), device.maxWhiteBalanceGain),
                greenGain: min(max(gains.greenGain, 1), device.maxWhiteBalanceGain),
                blueGain: min(max(gains.blueGain, 1), device.maxWhiteBalanceGain)
            )
            device.setWhiteBalanceModeLocked(with: supportedGains)
        }
    }

    private func applyAfterCameraSwitch(
        _ whiteBalance: WhiteBalanceSetting,
        to device: AVCaptureDevice
    ) {
        switch whiteBalance {
        case .auto, .continuousAuto:
            if device.isWhiteBalanceModeSupported(.autoWhiteBalance) {
                device.whiteBalanceMode = .autoWhiteBalance
            } else {
                apply(whiteBalance, to: device)
            }
        case .locked, .manual:
            apply(whiteBalance, to: device)
        }
    }

    private func apply(
        _ zoomFactor: CGFloat,
        to device: AVCaptureDevice
    ) {
        let deviceZoomFactor = zoomFactor / displayZoomFactorMultiplier(for: device)

        device.videoZoomFactor = min(
            max(deviceZoomFactor, device.minAvailableVideoZoomFactor),
            device.maxAvailableVideoZoomFactor
        )
    }

    private func displayZoomFactorMultiplier(for device: AVCaptureDevice) -> CGFloat {
        if device.isVirtualDevice, device.displayVideoZoomFactorMultiplier > 0 {
            return device.displayVideoZoomFactorMultiplier
        }

        return CGFloat(deviceLookup.displayZoomFactor(for: device) ?? 1)
    }

    @discardableResult
    private func addInput(for device: AVCaptureDevice) throws(CameraSessionError) -> AVCaptureDeviceInput {
        let input: AVCaptureDeviceInput

        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw .addInputFailed
        }

        guard captureSession.canAddInput(input) else {
            throw .addInputFailed
        }

        captureSession.addInput(input)
        return input
    }

    private func addOutput(_ output: AVCaptureOutput) throws(CameraSessionError) {
        guard captureSession.canAddOutput(output) else {
            throw .addOutputFailed
        }

        captureSession.addOutput(output)
    }

    private func checkCaptureAuthorizationStatus() async throws(CameraSessionError) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            try await requestCaptureAuthorization()
        case .denied, .restricted:
            throw .unauthorized
        @unknown default:
            throw .unauthorized
        }
    }

    private func requestCaptureAuthorization() async throws(CameraSessionError) {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            throw .unauthorized
        }
    }
}

extension CameraSession: PhotoCapturing {
    func capturePhoto(
        flashMode: CameraFlashMode,
        aspectRatio: CameraAspectRatio,
        outputFormat: PhotoOutputFormat,
        resolution: PhotoResolution?,
        contentAwareCorrection: ContentAwareCorrection,
        previewHandler: @escaping @Sendable (CGImage) -> Void
    ) async throws -> Photo {
        guard !isCapturingPhoto, !isRecordingVideo else {
            throw CameraSessionError.operationInProgress
        }
        isCapturingPhoto = true
        defer { isCapturingPhoto = false }

        let supportedFlashMode: CameraFlashMode

        if photoCaptureService.supportsFlashMode(flashMode) {
            supportedFlashMode = flashMode
        } else {
            supportedFlashMode = .off
        }

        return try await photoCaptureService.capturePhoto(
            flashMode: supportedFlashMode,
            aspectRatio: aspectRatio,
            outputFormat: outputFormat,
            resolution: resolution,
            contentAwareCorrection: contentAwareCorrection,
            previewHandler: previewHandler
        )
    }
}


extension CameraSession: VideoRecording {
    func recordVideo(to url: URL, didStart: @escaping @Sendable () -> Void) async throws {
        try Task.checkCancellation()
        guard !isCapturingPhoto, !isRecordingVideo else { throw VideoCaptureError.operationInProgress }
        guard isSetUp, captureSession.isRunning,
              AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
              activeVideoInput != nil else {
            throw VideoCaptureError.recordingFailed
        }
        isRecordingVideo = true
        isStoppingVideo = false
        let id = UUID()
        recordingID = id
        defer {
            removeAudioInput()
            if manuallyActivatedAudio {
                VideoMicrophoneRouter.release(captureSession: captureSession)
                manuallyActivatedAudio = false
            }
            isRecordingVideo = false
            recordingID = nil
            isStoppingVideo = false
        }
        guard configuredSettings.captureMode == .video else { throw VideoCaptureError.unsupportedConfiguration }
        try configureAudio()
        try videoCaptureService.configure(configuredSettings.video)
        if let connection = videoCaptureService.output.connection(with: .video) {
            let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 90
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
        try await videoCaptureService.record(to: url) { [weak self] in
            Task { await self?.videoRecordingDidStart(id: id, didStart: didStart) }
        }
    }

    func stopVideoRecording() {
        guard isRecordingVideo else { return }
        isStoppingVideo = true
        videoCaptureService.stopRecording()
    }

    private func videoRecordingDidStart(id: UUID, didStart: @Sendable () -> Void) {
        guard recordingID == id else { return }
        didStart()
        // A stop can arrive before AVFoundation reports that recording started.
        if isStoppingVideo { videoCaptureService.stopRecording() }
    }

    private func configureAudio() throws {
        manuallyActivatedAudio = try VideoMicrophoneRouter.configure(
            configuredSettings.video.microphone, cameraPosition: activeVideoInput?.device.position ?? .unspecified,
            captureSession: captureSession
        )
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            throw VideoCaptureError.recordingFailed
        }
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        if activeAudioInput == nil { activeAudioInput = try addInput(for: microphone) }
    }

    private func removeAudioInput() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        if let activeAudioInput {
            captureSession.removeInput(activeAudioInput)
            self.activeAudioInput = nil
        }
    }

}
