//
//  VideoPermissionsTests.swift
//  Essential CamTests
//
//  Created by Alexander López.
//

import Foundation
import Testing
@testable import Essential_Cam

struct VideoPermissionsTests {
    @Test @MainActor func settingsEditingDoesNotRequestVideoPermissionsAndRestoresEntryMode() async {
        let permissions = TestVideoPermissions(statuses: [.notDetermined, .notDetermined, .notDetermined])
        let model = CameraViewModel(videoPermissions: permissions)
        await model.controls.synchronizeWithCamera()
        model.controls.setPhotoTimer(.tenSeconds)
        model.beginSettingsEditing()
        await model.selectCaptureMode(.video)
        await model.checkVideoPermissions()
        #expect(await permissions.requests.isEmpty)
        #expect(await permissions.checks.isEmpty)
        #expect(model.selectedCaptureMode == .video)
        await model.endSettingsEditing()
        #expect(model.selectedCaptureMode == .photo)
        #expect(model.controls.settings.photoTimer == .tenSeconds)
        #expect(!model.isEditingSettings)
        await model.selectCaptureMode(.video)
        model.beginSettingsEditing()
        await model.selectCaptureMode(.photo)
        await model.endSettingsEditing()
        #expect(model.selectedCaptureMode == .video)
        #expect(!model.isEditingSettings)
    }

    @Test @MainActor func onboardingWelcomeDoesNotCheckOrRequestPermissions() async {
        let permissions = TestVideoPermissions(statuses: [.notDetermined, .notDetermined, .notDetermined])
        let model = OnboardingViewModel(permissions: permissions)
        await model.refreshStatus()
        #expect(model.permission == nil)
        #expect(!model.isPrimaryActionDisabled)
        #expect(await permissions.checks.isEmpty)
        #expect(await permissions.requests.isEmpty)
        await model.performPrimaryAction()
        #expect(model.permission == .camera)
        #expect(model.isPrimaryActionDisabled)
        #expect(await permissions.requests.isEmpty)
    }

    @Test @MainActor func onboardingAdvancesThroughDeniedPermissionsAndCompletesOnce() async {
        let permissions = TestVideoPermissions(statuses: [.denied, .denied, .denied])
        let model = OnboardingViewModel(permissions: permissions)
        await model.performPrimaryAction()
        for permission in [VideoPermission.camera, .photoLibrary, .microphone] {
            #expect(model.permission == permission)
            #expect(model.isPrimaryActionDisabled)
            await model.refreshStatus()
            #expect(model.status == .denied)
            #expect(!model.isPrimaryActionDisabled)
            #expect(!model.isComplete)
            await model.performPrimaryAction()
        }
        #expect(model.isComplete)
        #expect(model.isPrimaryActionDisabled)
        await model.performPrimaryAction()
        #expect(model.step == model.permissionCount)
        #expect(await permissions.requests.isEmpty)
    }

    @Test @MainActor func onboardingConcurrentActionDoesNotDuplicateRequestOrAdvance() async {
        let permissions = TestVideoPermissions(statuses: [.notDetermined, .authorized, .authorized], holdRequest: true)
        let model = OnboardingViewModel(permissions: permissions)
        await model.performPrimaryAction()
        await model.refreshStatus()
        let task = Task { await model.performPrimaryAction() }
        await permissions.waitForRequest()
        await model.performPrimaryAction()
        await model.refreshStatus()
        #expect(model.isRequesting)
        #expect(model.permission == .camera)
        #expect(await permissions.requests == [.camera])
        await permissions.finishRequest()
        await task.value
        #expect(model.status == .authorized)
        #expect(!model.isRequesting)
        #expect(model.permission == .camera)
        await model.performPrimaryAction()
        #expect(model.permission == .photoLibrary)
    }

    @Test @MainActor func leavingOnboardingCancelsPendingResultAndAllowsStatusRefresh() async {
        let permissions = TestVideoPermissions(statuses: [.notDetermined, .authorized, .authorized], holdRequest: true)
        let model = OnboardingViewModel(permissions: permissions)
        await model.performPrimaryAction()
        await model.refreshStatus()
        let task = Task { await model.performPrimaryAction() }
        await permissions.waitForRequest()
        model.cancelPendingOperations()
        await permissions.finishRequest()
        await task.value
        #expect(model.status == .notDetermined)
        #expect(!model.isRequesting)
        #expect(!model.isComplete)
        #expect(model.permission == .camera)
        await model.refreshStatus()
        #expect(model.status == .authorized)
        #expect(await permissions.requests == [.camera])
    }

    @Test(arguments: [CapturePermissionStatus.authorized, .denied])
    func onboardingDoesNotRequestDecidedPermission(_ status: CapturePermissionStatus) async throws {
        let permissions = TestVideoPermissions(statuses: [status, .notDetermined, .notDetermined])
        #expect(try await RequestOnboardingPermissionUseCase(permissions: permissions).execute(.camera) == status)
        #expect(await permissions.requests.isEmpty)
        #expect(await permissions.checks == [.camera])
    }

    @Test func onboardingDenialDoesNotRequestOtherPermissions() async throws {
        let permissions = TestVideoPermissions(
            statuses: [.notDetermined, .notDetermined, .notDetermined], requestResult: .denied
        )
        #expect(try await RequestOnboardingPermissionUseCase(permissions: permissions).execute(.photoLibrary) == .denied)
        #expect(await permissions.requests == [.photoLibrary])
        #expect(try await RequestOnboardingPermissionUseCase(permissions: permissions).execute(.camera) == .denied)
        #expect(await permissions.requests == [.photoLibrary, .camera])
    }

    @Test func onboardingCancellationDoesNotCompletePermissionStep() async throws {
        let permissions = TestVideoPermissions(statuses: [.notDetermined, .notDetermined, .notDetermined], holdRequest: true)
        let task = Task { try await RequestOnboardingPermissionUseCase(permissions: permissions).execute(.camera) }
        await permissions.waitForRequest()
        task.cancel()
        await permissions.finishRequest()
        do {
            _ = try await task.value
            Issue.record("Canceled onboarding must not advance")
        } catch is CancellationError {}
        #expect(await permissions.requests == [.camera])
    }

    @Test func authorizedPermissionsDoNotPrompt() async throws {
        let permissions = TestVideoPermissions(statuses: [.authorized, .authorized, .authorized])
        let missing = try await CheckVideoPermissionsUseCase(permissions: permissions).execute()
        #expect(missing == nil)
        #expect(await permissions.requests.isEmpty)
        #expect(await permissions.checks == VideoPermission.allCases)
    }

    @Test func undecidedPermissionsAreRequestedInOrder() async throws {
        let permissions = TestVideoPermissions(statuses: [.notDetermined, .notDetermined, .notDetermined])
        #expect(try await CheckVideoPermissionsUseCase(permissions: permissions).execute() == nil)
        #expect(await permissions.requests == VideoPermission.allCases)
    }

    @Test(arguments: VideoPermission.allCases)
    func deniedPermissionStopsRemainingPrompts(_ denied: VideoPermission) async throws {
        let statuses = VideoPermission.allCases.map { $0 == denied ? CapturePermissionStatus.denied : .authorized }
        let permissions = TestVideoPermissions(statuses: statuses)
        #expect(try await CheckVideoPermissionsUseCase(permissions: permissions).execute() == denied)
        #expect(await permissions.requests.isEmpty)
    }

    @Test func microphoneDenialDoesNotRequestPhotos() async throws {
        let permissions = TestVideoPermissions(
            statuses: [.authorized, .notDetermined, .notDetermined],
            requestResult: .denied
        )
        #expect(try await CheckVideoPermissionsUseCase(permissions: permissions).execute() == .microphone)
        #expect(await permissions.requests == [.microphone])
        #expect(await permissions.checks == [.camera, .microphone])
    }

    @Test func statusOnlyCheckDoesNotPrompt() async throws {
        let permissions = TestVideoPermissions(statuses: [.authorized, .notDetermined, .notDetermined])
        #expect(try await CheckVideoPermissionsUseCase(permissions: permissions)
            .execute(requestIfNeeded: false) == .microphone)
        #expect(await permissions.requests.isEmpty)
    }

    @Test func cancellationStopsRemainingPrompts() async throws {
        let permissions = TestVideoPermissions(statuses: [.authorized, .notDetermined, .notDetermined], holdRequest: true)
        let task = Task { try await CheckVideoPermissionsUseCase(permissions: permissions).execute() }
        await permissions.waitForRequest()
        task.cancel()
        await permissions.finishRequest()
        do {
            _ = try await task.value
            Issue.record("A canceled permission check must not succeed")
        } catch is CancellationError {}
        #expect(await permissions.requests == [.microphone])
    }

    @Test @MainActor func photoModeDoesNotRequestVideoPermissions() async {
        let permissions = TestVideoPermissions(statuses: [.notDetermined, .notDetermined, .notDetermined])
        let model = CameraViewModel(videoPermissions: permissions)
        await model.checkVideoPermissions()
        #expect(await permissions.checks.isEmpty)
        #expect(!model.videoPermissionsGranted)
    }

    @Test @MainActor func deniedMicrophoneAllowsReturnToPhotoAndRecheckAfterSettings() async {
        let permissions = TestVideoPermissions(statuses: [.authorized, .denied, .authorized])
        let model = CameraViewModel(videoPermissions: permissions)
        await model.selectCaptureMode(.video)
        await model.checkVideoPermissions()
        #expect(model.activeAlert == .videoPermissionRequired(.microphone))
        #expect(!model.videoPermissionsGranted)
        #expect(!model.isCheckingVideoPermissions)
        await model.selectCaptureMode(.photo)
        #expect(model.selectedCaptureMode == .photo)
        #expect(model.activeAlert == nil)
        await permissions.setStatus(.authorized, for: .microphone)
        await model.selectCaptureMode(.video)
        await model.checkVideoPermissions()
        #expect(model.videoPermissionsGranted)
        await permissions.setStatus(.denied, for: .microphone)
        await model.checkVideoPermissions()
        #expect(!model.videoPermissionsGranted)
        #expect(model.activeAlert == .videoPermissionRequired(.microphone))
    }

    @Test @MainActor func concurrentRecheckDoesNotDuplicatePermissionRequest() async {
        let permissions = TestVideoPermissions(statuses: [.authorized, .notDetermined, .authorized], holdRequest: true)
        let model = CameraViewModel(videoPermissions: permissions)
        await model.selectCaptureMode(.video)
        let task = Task { await model.checkVideoPermissions() }
        await permissions.waitForRequest()
        await model.checkVideoPermissions()
        #expect(model.isCheckingVideoPermissions)
        #expect(await permissions.requests == [.microphone])
        await permissions.finishRequest()
        await task.value
        #expect(model.videoPermissionsGranted)
        #expect(!model.isCheckingVideoPermissions)
    }
}

private actor TestVideoPermissions: VideoPermissionsProviding {
    private var statuses: [CapturePermissionStatus]
    private let requestResult: CapturePermissionStatus
    private let holdRequest: Bool
    private var requestContinuation: CheckedContinuation<Void, Never>?
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private(set) var requests: [VideoPermission] = []
    private(set) var checks: [VideoPermission] = []

    init(statuses: [CapturePermissionStatus], requestResult: CapturePermissionStatus = .authorized, holdRequest: Bool = false) {
        self.statuses = statuses
        self.requestResult = requestResult
        self.holdRequest = holdRequest
    }

    func status(for permission: VideoPermission) -> CapturePermissionStatus {
        checks.append(permission)
        return statuses[index(for: permission)]
    }

    func request(_ permission: VideoPermission) async -> CapturePermissionStatus {
        requests.append(permission)
        if holdRequest {
            await withCheckedContinuation { continuation in
                requestContinuation = continuation
                startedContinuation?.resume()
                startedContinuation = nil
            }
        }
        statuses[index(for: permission)] = requestResult
        return requestResult
    }

    func waitForRequest() async {
        guard requests.isEmpty else { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    func finishRequest() {
        requestContinuation?.resume()
        requestContinuation = nil
    }

    func setStatus(_ status: CapturePermissionStatus, for permission: VideoPermission) {
        statuses[index(for: permission)] = status
    }

    private func index(for permission: VideoPermission) -> Int {
        VideoPermission.allCases.firstIndex(of: permission)!
    }
}
