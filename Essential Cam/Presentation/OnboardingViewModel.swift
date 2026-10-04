import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var step = 0
    private(set) var status: CapturePermissionStatus?
    private(set) var isRequesting = false
    private(set) var isComplete = false

    private let permissionOrder: [VideoPermission] = [.camera, .photoLibrary, .microphone]
    private let permissions: any VideoPermissionsProviding
    @ObservationIgnored private var requestTask: Task<CapturePermissionStatus, Error>?
    @ObservationIgnored private var refreshGeneration = 0

    init(permissions: any VideoPermissionsProviding = DefaultOnboardingPermissions()) {
        self.permissions = permissions
    }

    var permission: VideoPermission? {
        step == 0 ? nil : permissionOrder[step - 1]
    }

    var permissionCount: Int {
        permissionOrder.count
    }

    var isPrimaryActionDisabled: Bool {
        isComplete || isRequesting || (permission != nil && status == nil)
    }

    var isLastPermission: Bool {
        step == permissionCount
    }

    func refreshStatus() async {
        guard let permission, !isRequesting, !isComplete else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        let currentStep = step
        let result = await permissions.status(for: permission)
        guard !Task.isCancelled, generation == refreshGeneration,
              step == currentStep, !isRequesting, !isComplete else { return }
        status = result
    }

    func performPrimaryAction() async {
        guard !Task.isCancelled, !isPrimaryActionDisabled else { return }
        refreshGeneration += 1
        guard let permission else {
            step = 1
            return
        }
        if status == .notDetermined {
            isRequesting = true
            defer {
                isRequesting = false
                requestTask = nil
            }
            // Retain only the active permission task so leaving onboarding can
            // cancel it without allowing another system prompt to overlap.
            let task = Task {
                try await RequestOnboardingPermissionUseCase(permissions: permissions)
                    .execute(permission)
            }
            requestTask = task
            do {
                status = try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: {
                    task.cancel()
                }
            } catch {
                // Cancellation must not advance the step or publish a stale result.
                return
            }
        } else if isLastPermission {
            isComplete = true
        } else {
            status = nil
            step += 1
        }
    }

    func cancelPendingOperations() {
        refreshGeneration += 1
        requestTask?.cancel()
    }
}
