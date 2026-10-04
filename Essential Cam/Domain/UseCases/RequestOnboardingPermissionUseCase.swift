struct RequestOnboardingPermissionUseCase {
    let permissions: any VideoPermissionsProviding

    func execute(_ permission: VideoPermission) async throws -> CapturePermissionStatus {
        try Task.checkCancellation()
        let status = await permissions.status(for: permission)
        try Task.checkCancellation()
        guard status == .notDetermined else { return status }
        let result = await permissions.request(permission)
        try Task.checkCancellation()
        return result
    }
}
