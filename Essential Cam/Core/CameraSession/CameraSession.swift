//
//  CameraSession.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

@preconcurrency import AVFoundation
import Foundation

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

    func selectCamera(id: Camera.ID) throws(CameraSessionError) {
        guard isSetUp else {
            throw .setupFailed
        }

        guard let device = selectedCameraDevices.first(where: { $0.uniqueID == id }) else {
            throw .cameraNotFound
        }

        guard activeVideoInput?.device.uniqueID != id else { return }

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

    private var selectedCameraDevices: [AVCaptureDevice] {
        switch selectedCameraPosition {
        case .front:
            return deviceLookup.frontCameras
        case .back:
            return deviceLookup.backCameras
        }
    }

    private var captureComponents: [any CameraCaptureComponent] {
        [photoCaptureService, videoCaptureService]
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
    func capturePhoto() async throws -> Photo {
        try await photoCaptureService.capturePhoto()
    }
}
