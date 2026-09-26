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

actor CameraSession {
    nonisolated let captureSession: AVCaptureSession

    private let sessionQueue = DispatchSerialQueue(
        label: "com.alexanderlopez.Essential-Cam.capture-session"
    )
    private let deviceLookup: any CameraDeviceLookup
    private let photoCaptureService: any PhotoCaptureService
    private let videoCaptureService: any VideoCaptureService
    
    private var activeVideoInput: AVCaptureDeviceInput?
    private var isSetUp = false
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
        self.deviceLookup = deviceLookup
        self.photoCaptureService = photoCaptureService
        self.videoCaptureService = videoCaptureService
    }

    func start() async throws(CameraSessionError) {
        try await checkCaptureAuthorizationStatus()

        guard !captureSession.isRunning else { return }

        try setUp()
        captureSession.startRunning()
    }

    func stop() {
        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
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

    func exposureCapabilities() -> CameraExposureCapabilities? {
        guard let device = activeVideoInput?.device else { return nil }

        return CameraExposureCapabilities(
            exposureBiasRange: device.minExposureTargetBias...device.maxExposureTargetBias,
            isoRange: device.activeFormat.minISO...device.activeFormat.maxISO,
            durationRange: device.activeFormat.minExposureDuration.seconds...device.activeFormat.maxExposureDuration.seconds,
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
        guard let device = activeVideoInput?.device else { return nil }

        let currentValues = device.temperatureAndTintValues(
            for: device.deviceWhiteBalanceGains
        )

        return CameraWhiteBalanceCapabilities(
            supportsContinuousAutoWhiteBalance: device.isWhiteBalanceModeSupported(
                .continuousAutoWhiteBalance
            ),
            supportsLockedWhiteBalance: device.isWhiteBalanceModeSupported(.locked),
            currentTemperature: currentValues.temperature,
            currentTint: currentValues.tint
        )
    }

    func apply(_ settings: CameraSettings) throws(CameraSessionError) {
        guard isSetUp, let device = activeVideoInput?.device else {
            throw .setupFailed
        }

        do {
            try device.lockForConfiguration()
        } catch {
            throw .configurationFailed
        }

        defer { device.unlockForConfiguration() }

        apply(settings.exposure, to: device)
        apply(settings.focus, to: device)
        apply(settings.whiteBalance, to: device)
        apply(settings.avFoundationZoomFactor, to: device)
    }

    func applyAfterCameraSwitch(
        _ settings: CameraSettings
    ) throws(CameraSessionError) {
        guard isSetUp, let device = activeVideoInput?.device else {
            throw .setupFailed
        }

        do {
            try device.lockForConfiguration()
        } catch {
            throw .configurationFailed
        }

        defer { device.unlockForConfiguration() }

        applyAfterCameraSwitch(settings.exposure, to: device)
        applyAfterCameraSwitch(settings.focus, to: device)
        applyAfterCameraSwitch(settings.whiteBalance, to: device)
        apply(settings.avFoundationZoomFactor, to: device)
    }

    func selectCamera(id: Camera.ID) throws(CameraSessionError) {
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

        for capture in captureComponents {
            capture.updateConfiguration(for: device)
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
        [photoCaptureService, videoCaptureService]
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
                device.activeFormat.maxExposureDuration.seconds
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
        let deviceZoomFactor: CGFloat
        if device.isVirtualDevice, device.displayVideoZoomFactorMultiplier > 0 {
            // Virtual devices use an internal scale that starts at their widest
            // constituent camera. Keep CameraSettings on the user-facing scale,
            // where 1× matches the main wide-angle camera.
            deviceZoomFactor = zoomFactor / device.displayVideoZoomFactorMultiplier
        } else {
            deviceZoomFactor = zoomFactor
        }

        device.videoZoomFactor = min(
            max(deviceZoomFactor, device.minAvailableVideoZoomFactor),
            device.maxAvailableVideoZoomFactor
        )
    }

    @discardableResult
    private func addInput(for device: AVCaptureDevice) throws(CameraSessionError) -> AVCaptureDeviceInput {
        let input: AVCaptureDeviceInput

        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
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
        aspectRatio: CameraAspectRatio
    ) async throws -> Photo {
        let supportedFlashMode: CameraFlashMode

        if photoCaptureService.supportsFlashMode(flashMode) {
            supportedFlashMode = flashMode
        } else {
            supportedFlashMode = .off
        }

        return try await photoCaptureService.capturePhoto(
            flashMode: supportedFlashMode,
            aspectRatio: aspectRatio
        )
    }
}
