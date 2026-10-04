import Foundation
import Testing
@testable import Essential_Cam

struct VideoPermissionsTests {
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
        model.selectCaptureMode(.video)
        await model.checkVideoPermissions()
        #expect(model.activeAlert == .videoPermissionRequired(.microphone))
        #expect(!model.videoPermissionsGranted)
        #expect(!model.isCheckingVideoPermissions)
        model.selectCaptureMode(.photo)
        #expect(model.selectedCaptureMode == .photo)
        #expect(model.activeAlert == nil)
        await permissions.setStatus(.authorized, for: .microphone)
        model.selectCaptureMode(.video)
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
        model.selectCaptureMode(.video)
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
