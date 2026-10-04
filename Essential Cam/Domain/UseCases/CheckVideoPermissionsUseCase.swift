import Foundation

enum VideoPermission: CaseIterable, Sendable {
    case camera
    case microphone
    case photoLibrary
}

enum CapturePermissionStatus: Sendable {
    case authorized
    case notDetermined
    case denied
}

protocol VideoPermissionsProviding: Sendable {
    func status(for permission: VideoPermission) async -> CapturePermissionStatus
    func request(_ permission: VideoPermission) async -> CapturePermissionStatus
}

struct CheckVideoPermissionsUseCase {
    let permissions: any VideoPermissionsProviding

    /// Returns the first unavailable permission. Already decided permissions
    /// never trigger another system prompt.
    func execute(requestIfNeeded: Bool = true) async throws -> VideoPermission? {
        for permission in VideoPermission.allCases {
            try Task.checkCancellation()
            var status = await permissions.status(for: permission)
            try Task.checkCancellation()
            if status == .notDetermined, requestIfNeeded {
                status = await permissions.request(permission)
                try Task.checkCancellation()
            }
            guard status == .authorized else { return permission }
        }
        return nil
    }
}
