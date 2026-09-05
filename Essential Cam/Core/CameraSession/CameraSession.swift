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

    private func setUp() throws(CameraSessionError) {
        guard !isSetUp else { return }

        guard let defaultCamera = deviceLookup.mainBackCamera ?? deviceLookup.mainFrontCamera else {
            throw .setupFailed
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if #available(iOS 26.0, *) {
            captureSession.configuresApplicationAudioSessionForBluetoothHighQualityRecording = true
        }

        activeVideoInput = try addInput(for: defaultCamera)
        captureSession.sessionPreset = .photo

        let captures: [any CameraCaptureComponent] = [photoCaptureService, videoCaptureService]
        for capture in captures {
            try addOutput(capture.output)
            capture.updateConfiguration(for: defaultCamera)
        }

        isSetUp = true
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
