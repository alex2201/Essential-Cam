//
//  DefaultPhotoLibrary.swift
//  Essential Cam
//
//  Created by Alexander López on 06/09/26.
//

import Photos

struct DefaultPhotoLibrary: PhotoSaving {
    func save(_ photo: Photo) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest
                .forAsset()
                .addResource(
                    with: .photo,
                    data: photo.data,
                    options: nil
                )
        }
    }
}
