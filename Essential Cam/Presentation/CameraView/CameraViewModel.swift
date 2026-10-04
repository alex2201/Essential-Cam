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
    private(set) var availablePhotoOutputFormats: [PhotoOutputFormat] = []
    private(set) var availablePhotoResolutions: [PhotoResolution] = []
    private(set) var hasPendingPhoto = false
    private(set) var captureCountdown: Int?

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
    private let photoCoordinator: any PhotoCaptureCoordinating
    private let photoLibraryReader: any PhotoLibraryReading
    private let photoLibraryAuthorization: any PhotoLibraryAuthorizationProviding
    private let lifecycle = CameraLifecycleController()
    private var didRestorePendingPhoto = false
    private let logger = Logger(
        subsystem: "com.alexanderlopez.Essential-Cam",
        category: "camera.lifecycle"
    )

    var isPerformingCaptureOperation: Bool {
        operation == .capturingPhoto
    }

    var isSwitchingCameraPosition: Bool {
        operation == .switchingCamera
    }

    var isCameraInteractionDisabled: Bool {
        operation != .none || cameraStatus != .running || hasPendingPhoto
    }

    // MARK: - Initialization

    init(
        cameraSession: CameraSession = .init(),
        photoLibrary: DefaultPhotoLibrary = .init(),
        pendingPhotoStore: PendingPhotoStore = .init(),
        photoCoordinator: (any PhotoCaptureCoordinating)? = nil,
        photoLibraryReader: (any PhotoLibraryReading)? = nil,
        photoLibraryAuthorization: (any PhotoLibraryAuthorizationProviding)? = nil
    ) {
        self.cameraSession = cameraSession
        self.photoCoordinator = photoCoordinator ?? PhotoCaptureCoordinator(
            photoCapture: cameraSession,
            photoSaving: photoLibrary,
            pendingStore: pendingPhotoStore
        )
        self.photoLibraryReader = photoLibraryReader ?? photoLibrary
        self.photoLibraryAuthorization = photoLibraryAuthorization ?? photoLibrary
        controls = CameraControlsController(cameraSession: cameraSession)
    }

    isolated deinit {
        lifecycle.cancel()
    }

    // MARK: - Lifecycle

    func start() async {
        startMonitoringSessionEventsIfNeeded()
        await restorePendingPhotoIfNeeded()
        guard operation == .none else { return }
        operation = .starting
        cameraStatus = .starting
        defer { finishOperation() }
        do {
            try await cameraSession.start()
            availableCameras = await cameraSession.availableCameras()
            availableVirtualCameras = await cameraSession.availableVirtualCameras()
            selectedCamera = await cameraSession.selectedCamera()
            canSwitchCameraPosition = await cameraSession.canSwitchCameraPosition()
            await refreshPhotoOutputFormats()
            await refreshPhotoResolutions()
            await controls.synchronizeWithCamera()
            cameraStatus = .running
        } catch {
            // TODO: Track this error with the integrated logging service.
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
        guard lifecycle.updateScene(isActive: isActive, isBackground: isBackground) else {
            controls.cancelPendingChanges()
            return
        }

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
        await presentPendingPhotoActionsIfNeeded()
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
        guard operation == .none, cameraStatus == .running, !hasPendingPhoto else { return }
        operation = .capturingPhoto

        Task { [self] in
            defer { finishOperation() }

            do {
                let settings = controls.settings
                if settings.photoTimer != .off {
                    for remaining in stride(
                        from: settings.photoTimer.rawValue,
                        through: 1,
                        by: -1
                    ) {
                        captureCountdown = remaining
                        try await Task.sleep(for: .seconds(1))
                    }
                    captureCountdown = nil
                    guard cameraStatus == .running else { return }
                }
                let photo = try await photoCoordinator.capture(settings: settings)
                handleSavedPhoto(photo)
            } catch is CancellationError {
                captureCountdown = nil
            } catch let error as PhotoCaptureWorkflowError {
                // TODO: Track this error with the integrated logging service.
                await handlePhotoWorkflowError(error)
            } catch {
                // TODO: Track this error with the integrated logging service.
                activeAlert = .captureFailed
                logger.error("Couldn't capture photo: \(error.localizedDescription, privacy: .public)")
            }
        }
#endif
    }

    func retryPendingPhotoSave() {
        guard operation == .none, hasPendingPhoto else { return }
        activeAlert = nil
        operation = .capturingPhoto

        Task {
            defer { finishOperation() }
            do {
                let photo = try await photoCoordinator.retryPendingSave()
                hasPendingPhoto = false
                handleSavedPhoto(photo)
            } catch let error as PhotoCaptureWorkflowError {
                // TODO: Track this error with the integrated logging service.
                await handlePhotoWorkflowError(error)
            } catch {
                // TODO: Track this error with the integrated logging service.
                activeAlert = .pendingPhotoStorageFailed
            }
        }
    }

    func discardPendingPhoto() {
        guard operation == .none, hasPendingPhoto else { return }
        activeAlert = nil
        operation = .capturingPhoto
        Task {
            defer { finishOperation() }
            do {
                try await photoCoordinator.discardPendingPhoto()
                hasPendingPhoto = false
            } catch {
                // TODO: Track this error with the integrated logging service.
                hasPendingPhoto = true
                activeAlert = .pendingPhotoStorageFailed
            }
        }
    }

    private func restorePendingPhotoIfNeeded() async {
        guard !didRestorePendingPhoto else { return }
        didRestorePendingPhoto = true
        do {
            hasPendingPhoto = try await photoCoordinator.restorePendingPhoto() != nil
            if hasPendingPhoto {
                activeAlert = .photoSaveFailed
            }
        } catch {
            // TODO: Track this error with the integrated logging service.
            activeAlert = .pendingPhotoStorageFailed
        }
    }

    private func handlePhotoWorkflowError(_ error: PhotoCaptureWorkflowError) async {
        hasPendingPhoto = await photoCoordinator.hasPendingPhoto()
        switch error {
        case .photoLibraryUnauthorized:
            activeAlert = .photoLibraryUnauthorized
        case .photoLibrarySaveFailed:
            activeAlert = .photoSaveFailed
        case .pendingStorageFailed:
            activeAlert = .pendingPhotoStorageFailed
        case .pendingPhotoAlreadyExists:
            activeAlert = .photoSaveFailed
        case .captureFailed:
            activeAlert = .captureFailed
        }
        logger.error("Photo operation failed: \(String(describing: error), privacy: .public)")
    }

    private func handleSavedPhoto(_ photo: Photo) {
        hasPendingPhoto = false
        if let previewImage = photo.previewImage {
            capturedPhotoPreview = CapturedPhotoPreview(image: previewImage)
        }
        Task { await refreshRecentPhotoThumbnails() }
    }

    private func presentPendingPhotoActionsIfNeeded() async {
        guard hasPendingPhoto else { return }
        switch await photoLibraryAuthorization.addAuthorizationStatus() {
        case .authorized:
            activeAlert = .photoSaveFailed
        case .denied, .notDetermined:
            activeAlert = .photoLibraryUnauthorized
        }
    }

    func refreshRecentPhotoThumbnails() async {
        recentPhotoThumbnails = await photoLibraryReader.latestThumbnails(limit: 3)
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
                await refreshPhotoResolutions()
            } catch {
                // TODO: Track this error with the integrated logging service.
                activeAlert = .cameraSwitchFailed
                logger.error("Couldn't select camera: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func toggleCameraPosition() {
        guard canSwitchCameraPosition,
              operation == .none, cameraStatus == .running else { return }
        operation = .switchingCamera

        Task {
            defer {
                finishOperation()
            }

            do {
                try await cameraSession.toggleCameraPosition()
                availableCameras = await cameraSession.availableCameras()
                availableVirtualCameras = await cameraSession.availableVirtualCameras()
                selectedCamera = await cameraSession.selectedCamera()
                await controls.synchronizeWithCamera(afterCameraSwitch: true)
                await refreshPhotoOutputFormats()
                await refreshPhotoResolutions()
            } catch {
                // TODO: Track this error with the integrated logging service.
                activeAlert = .cameraSwitchFailed
                logger.error("Couldn't switch camera position: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func startMonitoringSessionEventsIfNeeded() {
        lifecycle.startMonitoring(events: cameraSession.events) { [weak self] event in
            await self?.handleSessionEvent(event)
        }
    }

    private func handleSessionEvent(_ event: CameraSessionEvent) async {
        switch event {
        case let .interrupted(reason):
            // Background transitions already hide the app. Avoid replacing the
            // preview with an interruption message that lingers on foreground.
            if lifecycle.isSceneActive || reason != .appInactive {
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
        guard let failure = lifecycle.recoveryToRun(
            for: failure,
            operationInProgress: operation != .none
        ) else { return }
        await recoverCamera(failure: failure)
    }

    private func finishOperation() {
        captureCountdown = nil
        operation = .none
        guard let failure = lifecycle.takePendingRecovery() else { return }
        Task { await recoverCamera(failure: failure) }
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
        lifecycle.scheduleHealthCheck { [weak self] in
            await self?.reconcileCameraState()
        }
    }

    private func recoverCamera(failure: CameraFailure = .cameraUnavailable) async {
        guard operation == .none else { return }
        operation = .recovering
        cameraStatus = .recovering
        defer { finishOperation() }

        do {
            try await cameraSession.start()
            availableCameras = await cameraSession.availableCameras()
            availableVirtualCameras = await cameraSession.availableVirtualCameras()
            selectedCamera = await cameraSession.selectedCamera()
            canSwitchCameraPosition = await cameraSession.canSwitchCameraPosition()
            await refreshPhotoOutputFormats()
            await refreshPhotoResolutions()
            await controls.synchronizeWithCamera()
            cameraStatus = .running
        } catch let error {
            // TODO: Track this error with the integrated logging service.
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

    private func refreshPhotoResolutions() async {
        availablePhotoResolutions = await cameraSession.availablePhotoResolutions()
        guard let largestResolution = availablePhotoResolutions.last else {
            controls.setPhotoResolution(nil)
            return
        }

        if let selectedResolution = controls.settings.photoResolution,
           availablePhotoResolutions.contains(selectedResolution) {
            return
        }
        controls.setPhotoResolution(largestResolution)
    }
}

enum CameraAlert: String, Identifiable {
    case captureFailed
    case photoSaveFailed
    case photoLibraryUnauthorized
    case pendingPhotoStorageFailed
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
