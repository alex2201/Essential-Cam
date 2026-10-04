import Photos

/// Onboarding includes gallery browsing, so it needs read/write access rather
/// than the add-only access checked when entering Video mode.
struct DefaultOnboardingPermissions: VideoPermissionsProviding {
    func status(for permission: VideoPermission) async -> CapturePermissionStatus {
        guard permission == .photoLibrary else {
            return await DefaultVideoPermissions().status(for: permission)
        }
        return libraryStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func request(_ permission: VideoPermission) async -> CapturePermissionStatus {
        guard permission == .photoLibrary else {
            return await DefaultVideoPermissions().request(permission)
        }
        return libraryStatus(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    private func libraryStatus(_ status: PHAuthorizationStatus) -> CapturePermissionStatus {
        switch status {
        case .authorized, .limited: .authorized
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }
}
