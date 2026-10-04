import Foundation

enum PhotoCaptureWorkflowError: Error, Equatable {
    case pendingPhotoAlreadyExists
    case captureFailed
    case pendingStorageFailed
    case photoLibraryUnauthorized
    case photoLibrarySaveFailed
}

protocol PhotoCaptureCoordinating: Sendable {
    func capture(settings: CameraSettings) async throws -> Photo
    func restorePendingPhoto() async throws -> Photo?
    func retryPendingSave() async throws -> Photo
    func discardPendingPhoto() async throws
    func hasPendingPhoto() async -> Bool
}

actor PhotoCaptureCoordinator: PhotoCaptureCoordinating {
    private let photoCapture: any PhotoCapturing
    private let photoSaving: any PhotoSaving
    private let pendingStore: any PendingPhotoStoring
    private var pendingPhoto: Photo?

    init(
        photoCapture: any PhotoCapturing,
        photoSaving: any PhotoSaving,
        pendingStore: any PendingPhotoStoring
    ) {
        self.photoCapture = photoCapture
        self.photoSaving = photoSaving
        self.pendingStore = pendingStore
    }

    func capture(settings: CameraSettings) async throws -> Photo {
        guard pendingPhoto == nil else {
            throw PhotoCaptureWorkflowError.pendingPhotoAlreadyExists
        }

        let photo: Photo
        do {
            photo = try await photoCapture.capturePhoto(
                flashMode: settings.flashMode,
                aspectRatio: settings.aspectRatio,
                outputFormat: settings.photoOutputFormat,
                resolution: settings.photoResolution,
                contentAwareCorrection: settings.contentAwareCorrection,
                previewHandler: { _ in }
            )
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw PhotoCaptureWorkflowError.captureFailed
        }

        pendingPhoto = photo
        do {
            try await pendingStore.save(photo)
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw PhotoCaptureWorkflowError.pendingStorageFailed
        }

        return try await savePendingPhoto(photo)
    }

    func restorePendingPhoto() async throws -> Photo? {
        guard pendingPhoto == nil else { return pendingPhoto }
        do {
            pendingPhoto = try await pendingStore.load()
            return pendingPhoto
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw PhotoCaptureWorkflowError.pendingStorageFailed
        }
    }

    func retryPendingSave() async throws -> Photo {
        guard let pendingPhoto else {
            throw PhotoCaptureWorkflowError.captureFailed
        }

        do {
            try await pendingStore.save(pendingPhoto)
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw PhotoCaptureWorkflowError.pendingStorageFailed
        }
        return try await savePendingPhoto(pendingPhoto)
    }

    func discardPendingPhoto() async throws {
        do {
            try await pendingStore.discard()
            pendingPhoto = nil
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw PhotoCaptureWorkflowError.pendingStorageFailed
        }
    }

    func hasPendingPhoto() -> Bool {
        pendingPhoto != nil
    }

    private func savePendingPhoto(_ photo: Photo) async throws -> Photo {
        do {
            try await photoSaving.save(photo)
        } catch PhotoCaptureError.photoLibraryUnauthorized {
            // TODO: Track this error with the integrated logging service.
            throw PhotoCaptureWorkflowError.photoLibraryUnauthorized
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw PhotoCaptureWorkflowError.photoLibrarySaveFailed
        }

        pendingPhoto = nil
        do {
            try await pendingStore.discard()
        } catch {
            // TODO: Track this error with the integrated logging service.
            // The photo is already in the library, so cleanup must not turn a
            // successful save into a retry that would create a duplicate.
        }
        return photo
    }
}
