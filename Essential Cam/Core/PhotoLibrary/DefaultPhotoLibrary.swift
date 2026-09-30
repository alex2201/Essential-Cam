//
//  DefaultPhotoLibrary.swift
//  Essential Cam
//
//  Created by Alexander López on 06/09/26.
//

import Photos
import UIKit

struct PhotoLibraryThumbnail: Identifiable, @unchecked Sendable {
    let id: String
    let image: UIImage
    let aspectRatio: CGFloat
}

struct DefaultPhotoLibrary: PhotoSaving, PhotoLibraryReading, PhotoLibraryAuthorizationProviding {
    func save(_ photo: Photo) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoCaptureError.photoLibraryUnauthorized
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = photo.uniformTypeIdentifier
                PHAssetCreationRequest
                    .forAsset()
                    .addResource(
                        with: .photo,
                        data: photo.data,
                        options: options
                    )
            }
        } catch {
            // TODO: Track this error with the integrated logging service.
            throw PhotoCaptureError.photoLibrarySaveFailed
        }
    }

    func addAuthorizationStatus() async -> PhotoLibraryAuthorizationStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func latestThumbnails(limit: Int = 3) async -> [PhotoLibraryThumbnail] {
        let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return []
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = limit
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: false)
        ]

        let assets = PHAsset.fetchAssets(
            with: .image,
            options: fetchOptions
        )
        var thumbnails: [PhotoLibraryThumbnail] = []

        for index in 0..<assets.count {
            let asset = assets.object(at: index)
            if let thumbnail = await thumbnail(for: asset) {
                thumbnails.append(thumbnail)
            }
        }

        return thumbnails
    }

    private func thumbnail(for asset: PHAsset) async -> PhotoLibraryThumbnail? {
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .fast
        requestOptions.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 180, height: 180),
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, _ in
                guard let image else {
                    continuation.resume(returning: nil)
                    return
                }

                let aspectRatio = asset.pixelHeight > 0
                    ? CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
                    : 1
                continuation.resume(
                    returning: PhotoLibraryThumbnail(
                        id: asset.localIdentifier,
                        image: image,
                        aspectRatio: aspectRatio
                    )
                )
            }
        }
    }
}
