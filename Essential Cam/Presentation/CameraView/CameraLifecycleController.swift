import Foundation

/// Owns camera lifecycle observation and delayed health checks. It does not
/// mutate camera or view state; those decisions remain with CameraViewModel.
@MainActor
final class CameraLifecycleController {
    private var sessionEventsTask: Task<Void, Never>?
    private var foregroundHealthCheckTask: Task<Void, Never>?
    private(set) var isSceneActive = true
    private var pendingRecovery: CameraFailure?

    func startMonitoring(
        events: AsyncStream<CameraSessionEvent>,
        handler: @escaping @MainActor (CameraSessionEvent) async -> Void
    ) {
        guard sessionEventsTask == nil else { return }
        sessionEventsTask = Task {
            for await event in events {
                guard !Task.isCancelled else { return }
                await handler(event)
            }
        }
    }

    /// Returns whether foreground reconciliation should continue.
    func updateScene(isActive: Bool, isBackground: Bool) -> Bool {
        isSceneActive = isActive
        if isBackground {
            pendingRecovery = nil
            foregroundHealthCheckTask?.cancel()
            return false
        }
        return isActive
    }

    func scheduleHealthCheck(
        handler: @escaping @MainActor () async -> Void
    ) {
        foregroundHealthCheckTask?.cancel()
        foregroundHealthCheckTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(750))
            } catch {
                // TODO: Track unexpected cancellation errors with the integrated logging service.
                return
            }
            guard !Task.isCancelled, isSceneActive else { return }
            await handler()
        }
    }

    func recoveryToRun(
        for failure: CameraFailure,
        operationInProgress: Bool
    ) -> CameraFailure? {
        guard isSceneActive else { return nil }
        guard operationInProgress else { return failure }
        pendingRecovery = failure
        return nil
    }

    func takePendingRecovery() -> CameraFailure? {
        guard isSceneActive else { return nil }
        defer { pendingRecovery = nil }
        return pendingRecovery
    }

    func cancel() {
        sessionEventsTask?.cancel()
        foregroundHealthCheckTask?.cancel()
    }
}
