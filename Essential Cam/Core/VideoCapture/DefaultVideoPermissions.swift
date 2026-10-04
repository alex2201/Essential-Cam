import AVFoundation
import Photos

struct DefaultVideoPermissions: VideoPermissionsProviding {
    func status(for permission: VideoPermission) async -> CapturePermissionStatus {
        switch permission {
        case .camera:
            captureStatus(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone:
            captureStatus(AVCaptureDevice.authorizationStatus(for: .audio))
        case .photoLibrary:
            libraryStatus(PHPhotoLibrary.authorizationStatus(for: .addOnly))
        }
    }

    func request(_ permission: VideoPermission) async -> CapturePermissionStatus {
        switch permission {
        case .camera:
            await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        case .microphone:
            await AVCaptureDevice.requestAccess(for: .audio) ? .authorized : .denied
        case .photoLibrary:
            libraryStatus(await PHPhotoLibrary.requestAuthorization(for: .addOnly))
        }
    }

    private func captureStatus(_ status: AVAuthorizationStatus) -> CapturePermissionStatus {
        switch status {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
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
