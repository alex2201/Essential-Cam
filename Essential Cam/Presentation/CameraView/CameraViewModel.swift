//
//  CameraViewModel.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

@preconcurrency import AVFoundation
import Foundation
import OSLog

@MainActor
@Observable
final class CameraViewModel {
    // MARK: - View State

    var cameraStatus = CameraStatus.idle
    private(set) var operation = CameraOperation.none
    var activeAlert: CameraAlert?
    private(set) var capturedPhotoPreview: CapturedPhotoPreview?
    private(set) var recentPhotoThumbnails: [PhotoLibraryThumbnail] = []
    private(set) var captureOrientation = CaptureOrientation.portrait
    private(set) var availableCameras: [Camera] = []
    private(set) var availableVirtualCameras: [Camera] = []
    private(set) var selectedCamera: Camera?
    private(set) var canSwitchCameraPosition = false
    private(set) var isSwitchingCameraPosition = false
    private(set) var availablePhotoOutputFormats: [PhotoOutputFormat] = []

    var preferredVirtualCamera: Camera? {
        availableVirtualCameras.max {
            $0.virtualDevicePriority < $1.virtualDevicePriority
        }
    }

    // MARK: - Camera Controls

    let controls: CameraControlsController

    // MARK: - Preview

    var captureSession: AVCaptureSession {
        cameraSession.captureSession
    }

    // MARK: - Dependencies

    private let cameraSession: CameraSession
    private let photoLibrary: DefaultPhotoLibrary
    private let pendingPhotoStore: PendingPhotoStore
    private var sessionEventsTask: Task<Void, Never>?
    private var foregroundHealthCheckTask: Task<Void, Never>?
    private var pendingPhotoForSaving: Photo?
    private var didRestorePendingPhoto = false
    private var isSceneActive = true
    private var needsRecovery = false
    private let logger = Logger(
        subsystem: "com.alexanderlopez.Essential-Cam",
        category: "camera.lifecycle"
    )

    var isPerformingCaptureOperation: Bool {
        operation == .capturingPhoto
    }

    var isCameraInteractionDisabled: Bool {
        operation != .none || cameraStatus != .running
    }

    // MARK: - Initialization

    init(
        cameraSession: CameraSession = .init(),
        photoLibrary: DefaultPhotoLibrary = .init(),
        pendingPhotoStore: PendingPhotoStore = .init()
    ) {
        self.cameraSession = cameraSession
        self.photoLibrary = photoLibrary
        self.pendingPhotoStore = pendingPhotoStore
        controls = CameraControlsController(cameraSession: cameraSession)
    }

    isolated deinit {
        sessionEventsTask?.cancel()
        foregroundHealthCheckTask?.cancel()
    }

    // MARK: - Lifecycle

    func start() async {
        startMonitoringSessionEventsIfNeeded()
        await restorePendingPhotoIfNeeded()
        guard operation == .none else { return }
        cameraStatus = .starting
        do {
            try await cameraSession.start()
            availableCameras = await cameraSession.availableCameras()
            availableVirtualCameras = await cameraSession.availableVirtualCameras()
            selectedCamera = await cameraSession.selectedCamera()
            canSwitchCameraPosition = await cameraSession.canSwitchCameraPosition()
            await refreshPhotoOutputFormats()
            await controls.synchronizeWithCamera()
            cameraStatus = .running
        } catch {
            switch error {
            case .unauthorized:
                cameraStatus = .unauthorized
            case .setupFailed, .cameraNotFound, .addInputFailed,
                    .addOutputFailed, .configurationFailed, .operationInProgress:
                cameraStatus = .failed(.configuration)
            }
            logger.error("Couldn't start capture: \(error.localizedDescription, privacy: .public)")
        }
    }

    func handleScenePhase(isActive: Bool, isBackground: Bool) async {
        isSceneActive = isActive
        if isBackground {
            needsRecovery = false
            foregroundHealthCheckTask?.cancel()
            controls.cancelPendingChanges()
            return
        }

        guard isActive else { return }

        switch cameraStatus {
        case .unauthorized, .failed, .idle:
            await recoverCamera()
        case .interrupted(.appInactive):
            cameraStatus = .running
            scheduleForegroundHealthCheck()
        case .requestingPermission, .starting, .running, .interrupted, .recovering:
            scheduleForegroundHealthCheck()
        }
        await refreshRecentPhotoThumbnails()
    }

    func retryCamera() {
        activeAlert = nil
        Task { await recoverCamera() }
    }

    // MARK: - Photo Capture

    func captureAction() {
#if targetEnvironment(simulator)
        // Simulator builds are intended for reviewing the camera interface.
        // Photo capture requires camera hardware, so keep the shutter inert.
        return
#else
        guard operation == .none, cameraStatus == .running else { return }
        operation = .capturingPhoto

        Task { [self] in
            defer { finishOperation() }

            do {
                let photo = try await cameraSession.capturePhoto(
                    flashMode: controls.settings.flashMode,
                    aspectRatio: controls.settings.aspectRatio,
                    outputFormat: controls.settings.photoOutputFormat,
                    previewHandler: { _ in }
                )
                try await saveCapturedPhoto(photo)
            } catch let error as PhotoCaptureError {
                handlePhotoError(error)
            } catch {
                activeAlert = .captureFailed
                logger.error("Couldn't capture photo: \(error.localizedDescription, privacy: .public)")
            }
        }
#endif
    }

    func retryPendingPhotoSave() {
        guard operation == .none, let photo = pendingPhotoForSaving else { return }
        activeAlert = nil
        operation = .capturingPhoto

        Task {
            defer { finishOperation() }
            do {
                try await saveCapturedPhoto(photo)
            } catch let error as PhotoCaptureError {
                handlePhotoError(error)
            } catch {
                activeAlert = .photoSaveFailed
            }
        }
    }

    func discardPendingPhoto() {
        pendingPhotoForSaving = nil
        activeAlert = nil
        Task { await pendingPhotoStore.discard() }
    }

    private func saveCapturedPhoto(_ photo: Photo) async throws {
        do {
            try await pendingPhotoStore.save(photo)
            pendingPhotoForSaving = photo
            try await photoLibrary.save(photo)
            pendingPhotoForSaving = nil
            await pendingPhotoStore.discard()
            if let previewImage = photo.previewImage {
                capturedPhotoPreview = CapturedPhotoPreview(image: previewImage)
            }
            await refreshRecentPhotoThumbnails()
        } catch {
            pendingPhotoForSaving = photo
            throw error
        }
    }

    private func restorePendingPhotoIfNeeded() async {
        guard !didRestorePendingPhoto else { return }
        didRestorePendingPhoto = true
        guard let photo = await pendingPhotoStore.load() else { return }
        pendingPhotoForSaving = photo
        activeAlert = .photoSaveFailed
    }

    private func handlePhotoError(_ error: PhotoCaptureError) {
        switch error {
        case .photoLibraryUnauthorized:
            activeAlert = .photoLibraryUnauthorized
        case .photoLibrarySaveFailed:
            activeAlert = .photoSaveFailed
        case .noPhotoData, .photoProcessingFailed:
            activeAlert = .captureFailed
        }
        logger.error("Photo operation failed: \(String(describing: error), privacy: .public)")
    }

    func refreshRecentPhotoThumbnails() async {
        recentPhotoThumbnails = await DefaultPhotoLibrary().latestThumbnails()
    }

    // MARK: - Camera Selection

    func selectCamera(_ camera: Camera) {
        guard operation == .none, cameraStatus == .running else { return }
        operation = .switchingCamera
        Task {
            defer { finishOperation() }
            do {
                try await cameraSession.selectCamera(id: camera.id)
                let preferredZoomFactor: Double? = if case .virtual = camera.deviceKind {
                    1
                } else {
                    nil
                }
                await controls.synchronizeWithCamera(
                    afterCameraSwitch: true,
                    preferredZoomFactor: preferredZoomFactor
                )
                selectedCamera = camera
                await refreshPhotoOutputFormats()
            } catch {
                activeAlert = .cameraSwitchFailed
                logger.error("Couldn't select camera: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func toggleCameraPosition() {
        guard canSwitchCameraPosition, !isSwitchingCameraPosition,
              operation == .none, cameraStatus == .running else { return }
        isSwitchingCameraPosition = true
        operation = .switchingCamera

        Task {
            defer {
                isSwitchingCameraPosition = false
                finishOperation()
            }

            do {
                try await cameraSession.toggleCameraPosition()
                availableCameras = await cameraSession.availableCameras()
                availableVirtualCameras = await cameraSession.availableVirtualCameras()
                selectedCamera = await cameraSession.selectedCamera()
                await controls.synchronizeWithCamera(afterCameraSwitch: true)
                await refreshPhotoOutputFormats()
            } catch {
                activeAlert = .cameraSwitchFailed
                logger.error("Couldn't switch camera position: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func startMonitoringSessionEventsIfNeeded() {
        guard sessionEventsTask == nil else { return }
        sessionEventsTask = Task { [weak self, events = cameraSession.events] in
            for await event in events {
                guard !Task.isCancelled else { return }
                await self?.handleSessionEvent(event)
            }
        }
    }

    private func handleSessionEvent(_ event: CameraSessionEvent) async {
        switch event {
        case let .interrupted(reason):
            // Background transitions already hide the app. Avoid replacing the
            // preview with an interruption message that lingers on foreground.
            if isSceneActive || reason != .appInactive {
                cameraStatus = .interrupted(reason)
            }
            controls.cancelPendingChanges()
        case .interruptionEnded:
            scheduleForegroundHealthCheck()
        case .runtimeError(.mediaServicesWereReset):
            await requestRecovery(failure: .mediaServicesReset)
        case .runtimeError(.other):
            await requestRecovery(failure: .unknown)
        }
    }

    private func requestRecovery(
        failure: CameraFailure = .cameraUnavailable
    ) async {
        guard isSceneActive else { return }
        guard operation == .none else {
            needsRecovery = true
            return
        }
        await recoverCamera(failure: failure)
    }

    private func finishOperation() {
        operation = .none
        guard needsRecovery, isSceneActive else { return }
        needsRecovery = false
        Task { await recoverCamera() }
    }

    private func reconcileCameraState() async {
        let snapshot = await cameraSession.snapshot()
        if snapshot.isRunning {
            cameraStatus = .running
            return
        }
        await recoverCamera()
    }

    private func scheduleForegroundHealthCheck() {
        foregroundHealthCheckTask?.cancel()
        foregroundHealthCheckTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled, let self, isSceneActive else { return }
            await reconcileCameraState()
        }
    }

    private func recoverCamera(failure: CameraFailure = .cameraUnavailable) async {
        guard operation == .none else { return }
        operation = .recovering
        cameraStatus = .recovering
        defer { operation = .none }

        do {
            try await cameraSession.start()
            availableCameras = await cameraSession.availableCameras()
            availableVirtualCameras = await cameraSession.availableVirtualCameras()
            selectedCamera = await cameraSession.selectedCamera()
            canSwitchCameraPosition = await cameraSession.canSwitchCameraPosition()
            await refreshPhotoOutputFormats()
            await controls.synchronizeWithCamera()
            cameraStatus = .running
        } catch let error {
            switch error {
            case .unauthorized:
                cameraStatus = .unauthorized
            case .setupFailed, .cameraNotFound, .addInputFailed,
                    .addOutputFailed, .configurationFailed, .operationInProgress:
                cameraStatus = .failed(failure)
                activeAlert = .cameraRecoveryFailed
            }
            logger.error("Camera recovery failed: \(error.localizedDescription, privacy: .public)")
        }
    }


    private func refreshPhotoOutputFormats() async {
        availablePhotoOutputFormats = await cameraSession.availablePhotoOutputFormats()
        if !availablePhotoOutputFormats.contains(controls.settings.photoOutputFormat),
           let fallback = availablePhotoOutputFormats.first {
            controls.setPhotoOutputFormat(fallback)
        }
    }
}

enum CameraAlert: String, Identifiable {
    case captureFailed
    case photoSaveFailed
    case photoLibraryUnauthorized
    case cameraSwitchFailed
    case cameraRecoveryFailed

    var id: String { rawValue }
}

struct CapturedPhotoPreview: Identifiable {
    let id = UUID()
    let image: CGImage

    var aspectRatio: CGFloat {
        guard image.height > 0 else { return 1 }
        return CGFloat(image.width) / CGFloat(image.height)
    }
}

private extension Camera {
    var virtualDevicePriority: Int {
        switch deviceKind {
        case .physical:
            0
        case let .virtual(type):
            switch type {
            case .triple:
                3
            case .dualWide, .dual:
                2
            case .unknown:
                1
            }
        }
    }
}
