//
//  CameraViewModel.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

@preconcurrency import AVFoundation
import Foundation
import OSLog
import UIKit

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
    private(set) var hasPendingVideo = false
    private(set) var recordingStartedAt: Date?
    private(set) var captureCountdown: Int?
    private(set) var selectedCaptureMode: CaptureMode = .photo
    private(set) var isCheckingVideoPermissions = false
    private(set) var videoPermissionsGranted = false

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
    private let videoPermissions: any VideoPermissionsProviding
    private let videoCoordinator: any VideoCaptureCoordinating
    private var recordingTask: Task<Void, Never>?
    private var activeRecordingID: UUID?
    private var didRestorePendingVideo = false
    private var videoBackgroundTask = UIBackgroundTaskIdentifier.invalid
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
        operation != .none || cameraStatus != .running || hasPendingPhoto || hasPendingVideo
    }

    var isRecordingVideo: Bool { operation == .recordingVideo }

    var isVideoCaptureInProgress: Bool {
        switch operation {
        case .startingVideo, .recordingVideo, .finishingVideo, .savingVideo: true
        default: false
        }
    }

    var isVideoRecordDisabled: Bool {
        if isRecordingVideo { return false }
        return isCameraInteractionDisabled || !videoPermissionsGranted || isCheckingVideoPermissions
    }

    // MARK: - Initialization

    init(
        cameraSession: CameraSession = .init(),
        photoLibrary: DefaultPhotoLibrary = .init(),
        pendingPhotoStore: PendingPhotoStore = .init(),
        photoCoordinator: (any PhotoCaptureCoordinating)? = nil,
        photoLibraryReader: (any PhotoLibraryReading)? = nil,
        photoLibraryAuthorization: (any PhotoLibraryAuthorizationProviding)? = nil,
        videoPermissions: any VideoPermissionsProviding = DefaultVideoPermissions(),
        videoCoordinator: (any VideoCaptureCoordinating)? = nil
    ) {
        self.cameraSession = cameraSession
        self.photoCoordinator = photoCoordinator ?? PhotoCaptureCoordinator(
            photoCapture: cameraSession,
            photoSaving: photoLibrary,
            pendingStore: pendingPhotoStore
        )
        self.photoLibraryReader = photoLibraryReader ?? photoLibrary
        self.photoLibraryAuthorization = photoLibraryAuthorization ?? photoLibrary
        self.videoPermissions = videoPermissions
        self.videoCoordinator = videoCoordinator ?? VideoCaptureCoordinator(
            recording: cameraSession, saving: photoLibrary, store: PendingVideoStore()
        )
        controls = CameraControlsController(cameraSession: cameraSession)
    }

    isolated deinit {
        lifecycle.cancel()
    }

    // MARK: - Lifecycle

    func start() async {
        startMonitoringSessionEventsIfNeeded()
        await restorePendingPhotoIfNeeded()
        await restorePendingVideoIfNeeded()
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
        if isBackground, isVideoCaptureInProgress, videoBackgroundTask == .invalid {
            videoBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish video") { [weak self] in
                Task { @MainActor in self?.endVideoBackgroundTask() }
            }
        }
        if !isActive, isVideoCaptureInProgress {
            if operation == .startingVideo { recordingTask?.cancel() }
            stopVideoRecording()
        }
        guard lifecycle.updateScene(isActive: isActive, isBackground: isBackground) else {
            controls.cancelPendingChanges()
            return
        }

        switch cameraStatus {
        case .unauthorized, .failed, .idle:
            await recoverCamera()
        case .interrupted(.appInactive):
            scheduleForegroundHealthCheck()
        case .requestingPermission, .starting, .running, .interrupted, .recovering:
            scheduleForegroundHealthCheck()
        }
        await refreshRecentPhotoThumbnails()
        await presentPendingPhotoActionsIfNeeded()
        if hasPendingVideo { activeAlert = .videoSaveFailed }
        if selectedCaptureMode == .video, operation == .none {
            await checkVideoPermissions()
        }
    }

    func selectCaptureMode(_ mode: CaptureMode) {
        guard !isCheckingVideoPermissions, operation == .none, !hasPendingPhoto, !hasPendingVideo else { return }
        selectedCaptureMode = mode
        videoPermissionsGranted = false
        if case .videoPermissionRequired = activeAlert {
            activeAlert = nil
        }
    }

    func checkVideoPermissions(requestIfNeeded: Bool = true) async {
        guard selectedCaptureMode == .video, !isCheckingVideoPermissions, operation == .none else { return }
        isCheckingVideoPermissions = true
        videoPermissionsGranted = false
        defer { isCheckingVideoPermissions = false }

        do {
            let missing = try await CheckVideoPermissionsUseCase(
                permissions: videoPermissions
            ).execute(requestIfNeeded: requestIfNeeded)
            guard selectedCaptureMode == .video, !Task.isCancelled else { return }
            videoPermissionsGranted = missing == nil
            if case .videoPermissionRequired = activeAlert {
                activeAlert = nil
            }
            if let missing, activeAlert == nil {
                activeAlert = .videoPermissionRequired(missing)
            }
        } catch is CancellationError {
            // A mode change cancels the check, including remaining prompts.
        } catch {
            logger.error("Video permission check failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func retryCamera() {
        activeAlert = nil
        Task { await recoverCamera() }
    }

    // MARK: - Video Capture

    func recordVideoAction() {
        if isRecordingVideo {
            stopVideoRecording()
            return
        }
#if targetEnvironment(simulator)
        return
#else
        guard selectedCaptureMode == .video, !isVideoRecordDisabled, lifecycle.isSceneActive else { return }
        operation = .startingVideo
        let recordingID = UUID()
        activeRecordingID = recordingID
        controls.cancelPendingChanges()
        recordingTask = Task { [self] in
            defer {
                recordingStartedAt = nil
                endVideoBackgroundTask()
                recordingTask = nil
                activeRecordingID = nil
                finishOperation()
            }
            do {
                // Recheck authorization at the action boundary, including changes in Settings.
                if let missing = try await CheckVideoPermissionsUseCase(permissions: videoPermissions)
                    .execute(requestIfNeeded: false) {
                    videoPermissionsGranted = false
                    activeAlert = .videoPermissionRequired(missing)
                    return
                }
                try Task.checkCancellation()
                guard lifecycle.isSceneActive, cameraStatus == .running else { return }
                try await videoCoordinator.record(didStart: { [weak self] in
                    Task { @MainActor in
                        guard let self, self.activeRecordingID == recordingID, self.operation == .startingVideo else { return }
                        self.operation = .recordingVideo
                        self.recordingStartedAt = .now
                        if !self.lifecycle.isSceneActive { self.stopVideoRecording() }
                    }
                }, didFinish: { [weak self] in
                    Task { @MainActor in
                        guard let self, self.activeRecordingID == recordingID, self.isVideoCaptureInProgress else { return }
                        self.operation = .savingVideo
                        self.recordingStartedAt = nil
                    }
                })
                hasPendingVideo = false
                await refreshRecentPhotoThumbnails()
            } catch is CancellationError {
                // An interrupted start never begins another recording on foreground.
            } catch {
                hasPendingVideo = await videoCoordinator.hasPendingVideo()
                if case VideoCaptureError.pendingStorageFailed = error { hasPendingVideo = true }
                activeAlert = hasPendingVideo ? .videoSaveFailed : .videoRecordingFailed
                logger.error("Video capture workflow failed")
            }
            await controls.synchronizeWithCamera()
            await refreshPhotoOutputFormats()
            await refreshPhotoResolutions()
        }
#endif
    }

    private func endVideoBackgroundTask() {
        guard videoBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(videoBackgroundTask)
        videoBackgroundTask = .invalid
    }

    private func stopVideoRecording() {
        guard isVideoCaptureInProgress, operation != .finishingVideo, operation != .savingVideo else { return }
        operation = .finishingVideo
        Task { await cameraSession.stopVideoRecording() }
    }

    func retryPendingVideoSave() {
        guard operation == .none, hasPendingVideo else { return }
        operation = .savingVideo
        activeAlert = nil
        Task {
            defer { finishOperation() }
            do {
                try await videoCoordinator.retrySave()
                hasPendingVideo = false
                await refreshRecentPhotoThumbnails()
            } catch { activeAlert = .videoSaveFailed }
        }
    }

    func discardPendingVideo() {
        guard operation == .none, hasPendingVideo else { return }
        operation = .savingVideo
        activeAlert = nil
        Task {
            defer { finishOperation() }
            do {
                try await videoCoordinator.discard()
                hasPendingVideo = false
            } catch { activeAlert = .videoSaveFailed }
        }
    }

    private func restorePendingVideoIfNeeded() async {
        guard !didRestorePendingVideo else { return }
        didRestorePendingVideo = true
        do {
            hasPendingVideo = try await videoCoordinator.restorePendingVideo()
            if hasPendingVideo { activeAlert = .videoSaveFailed }
        } catch {
            hasPendingVideo = true
            activeAlert = .videoSaveFailed
        }
    }

    // MARK: - Photo Capture

    func captureAction() {
#if targetEnvironment(simulator)
        // Simulator builds are intended for reviewing the camera interface.
        // Photo capture requires camera hardware, so keep the shutter inert.
        return
#else
        guard selectedCaptureMode == .photo, operation == .none, cameraStatus == .running, !hasPendingPhoto, !hasPendingVideo else { return }
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
            if operation == .startingVideo { recordingTask?.cancel() }
            stopVideoRecording()
            // Background transitions already hide the app. Avoid replacing the
            // preview with an interruption message that lingers on foreground.
            if lifecycle.isSceneActive || reason != .appInactive {
                cameraStatus = .interrupted(reason)
            }
            controls.cancelPendingChanges()
        case .interruptionEnded:
            scheduleForegroundHealthCheck()
        case .runtimeError(.mediaServicesWereReset):
            if operation == .startingVideo { recordingTask?.cancel() }
            stopVideoRecording()
            await requestRecovery(failure: .mediaServicesReset)
        case .runtimeError(.other):
            if operation == .startingVideo { recordingTask?.cancel() }
            stopVideoRecording()
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
        if let failure = lifecycle.takePendingRecovery() {
            Task { await requestRecovery(failure: failure) }
        } else if lifecycle.takePendingReconciliation() {
            scheduleForegroundHealthCheck()
        }
    }

    private func reconcileCameraState() async {
        guard lifecycle.shouldReconcile(operationInProgress: operation != .none) else { return }
        let snapshot = await cameraSession.snapshot()
        // A capture or background transition can occur while awaiting the actor.
        guard lifecycle.shouldReconcile(operationInProgress: operation != .none) else { return }
        if snapshot.isInterrupted {
            if case .interrupted = cameraStatus { return }
            cameraStatus = .interrupted(.unknown)
        } else if snapshot.isAvailable {
            await controls.synchronizeWithCamera()
            let refreshedSnapshot = await cameraSession.snapshot()
            guard lifecycle.shouldReconcile(operationInProgress: operation != .none) else { return }
            if refreshedSnapshot.isInterrupted {
                cameraStatus = .interrupted(.unknown)
            } else if refreshedSnapshot.isAvailable {
                cameraStatus = .running
            } else {
                await requestRecovery()
            }
        } else {
            await requestRecovery()
        }
    }

    private func scheduleForegroundHealthCheck() {
        lifecycle.scheduleHealthCheck { [weak self] in
            await self?.reconcileCameraState()
        }
    }

    private func recoverCamera(failure: CameraFailure = .cameraUnavailable) async {
        guard lifecycle.isSceneActive, operation == .none else { return }
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
            let snapshot = await cameraSession.snapshot()
            guard lifecycle.isSceneActive else { return }
            cameraStatus = snapshot.isInterrupted ? .interrupted(.unknown)
                : (snapshot.isAvailable ? .running : .failed(failure))
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

enum CameraAlert: Equatable, Identifiable {
    case videoPermissionRequired(VideoPermission)
    case captureFailed
    case videoRecordingFailed
    case videoSaveFailed
    case photoSaveFailed
    case photoLibraryUnauthorized
    case pendingPhotoStorageFailed
    case cameraSwitchFailed
    case cameraRecoveryFailed

    var id: String { String(describing: self) }
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
