//
//  CaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

@preconcurrency import AVFoundation
import Foundation

actor CaptureService {
    private let captureSession: AVCaptureSession
    private var isSetUp = false
    private let sessionQueue = DispatchSerialQueue(label: "com.alexanderlopez.Essential-Cam.capture-session")
    private let deviceLookup: any CameraDeviceLookup
    private var activeVideoInput: AVCaptureDeviceInput?
    private let photoCapture: any PhotoCapture
    private let videoPreviewController: VideoPreviewController
    nonisolated let previewSource: PreviewSource

    private var currentDevice: AVCaptureDevice {
        guard let device = activeVideoInput?.device else {
            fatalError("No device found for current video input.")
        }
        return device
    }

    init(
        captureSession: AVCaptureSession = .init(),
        deviceLookup: any CameraDeviceLookup = DefaultCameraDeviceLookup(),
        photoCapture: any PhotoCapture = DefaultPhotoCapture(),
        videoPreviewController: VideoPreviewController,
        previewSource: PreviewSource
    ) {
        self.captureSession = captureSession
        self.deviceLookup = deviceLookup
        self.photoCapture = photoCapture
        self.videoPreviewController = videoPreviewController
        self.previewSource = previewSource
    }

    @MainActor
    init(
        captureSession: AVCaptureSession = .init(),
        deviceLookup: any CameraDeviceLookup = DefaultCameraDeviceLookup(),
        photoCapture: any PhotoCapture = DefaultPhotoCapture()
    ) {
        self.init(
            captureSession: captureSession,
            deviceLookup: deviceLookup,
            photoCapture: photoCapture,
            videoPreviewController: DefaultVideoPreviewController(),
            previewSource: DefaultPreviewSource(session: captureSession)
        )
    }

    func start() async throws(CaptureServiceError) {
        try await checkCaptureAuthorizationStatus()

        guard !captureSession.isRunning else { return }

        try await setUpSession()
        self.captureSession.startRunning()
    }

    private func setUpSession() async throws(CaptureServiceError) {
        guard !isSetUp else { return }

        do {
            guard let defaultCamera = deviceLookup.mainBackCamera ?? deviceLookup.mainFrontCamera else {
                throw CaptureServiceError.setupFailed
            }

            // Enable using AirPods as a high-quality lapel microphone.
            if #available(iOS 26.0, *) {
                captureSession.configuresApplicationAudioSessionForBluetoothHighQualityRecording = true
            }

            activeVideoInput = try addInput(for: defaultCamera)

            captureSession.sessionPreset = .photo

            try addOutput(photoCapture.output)
            await setUpVideoPreviewController()

            // Configure controls to use with the Camera Control.
            //            configureControls(for: defaultCamera)
            // Monitor the system-preferred camera state.
            //            monitorSystemPreferredCamera()
            // Configure a rotation coordinator for the default video device.
            //            await configureRotation(for: defaultCamera)
            // Observe changes to the default camera's subject area.
            //            observeSubjectAreaChanges(of: defaultCamera)
            // Update the service's advertised capabilities.
            //            updateCaptureCapabilities()

            isSetUp = true
        } catch {
            throw CaptureServiceError.setupFailed
        }
    }

    @discardableResult
    private func addInput(for device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            throw CaptureServiceError.addInputFailed
        }
        return input
    }

    // Adds an output to the capture session to connect the specified capture device, if allowed.
    private func addOutput(_ output: AVCaptureOutput) throws {
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        } else {
            throw CaptureServiceError.addOutputFailed
        }
    }

    private func setUpVideoPreviewController() async {
        // Access the capture session's connected preview layer.
        guard let previewLayer = captureSession.connections.compactMap({ $0.videoPreviewLayer }).first else {
            fatalError("The app is misconfigured. The capture session should have a connection to a preview layer.")
        }
        videoPreviewController.attach(to: previewLayer)
    }

    private func configureRotation(for device: AVCaptureDevice) async {
        videoPreviewController.configureRotation(for: device) { [weak self] angle in
            Task { await self?.updateCaptureRotation(angle) }
        }
    }

    private func updateCaptureRotation(_ angle: CGFloat) {
        // Update the orientation for all output services.
        photoCapture.setVideoRotationAngle(angle)
    }

    // MARK: - Authorization
    private func checkCaptureAuthorizationStatus() async throws(CaptureServiceError) {
        let videoAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch videoAuthorizationStatus {
        case .authorized:
            break
        case .notDetermined:
            try await requestCaptureAuthorization()
        case .denied, .restricted:
            throw .unauthorized
        @unknown default:
            fatalError()
        }
    }

    private func requestCaptureAuthorization() async throws(CaptureServiceError) {
        let isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        if !isAuthorized {
            throw .unauthorized
        }
    }
}

enum CaptureServiceError: Error {
    case unauthorized, setupFailed, addInputFailed, addOutputFailed
}
