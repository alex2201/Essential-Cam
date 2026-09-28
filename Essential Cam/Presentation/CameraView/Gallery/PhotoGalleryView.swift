//
//  PhotoGalleryView.swift
//  Essential Cam
//
//  Created by Codex on 27/09/26.
//

import SwiftUI
@preconcurrency import Photos

struct PhotoGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PhotoGalleryViewModel()

    private let columns = [
        GridItem(.adaptive(minimum: 105), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.assetCount == 0 {
                    ContentUnavailableView(
                        "No Photos",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text(viewModel.emptyStateDescription)
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(0..<viewModel.assetCount, id: \.self) { index in
                                PhotoGalleryCell(viewModel: viewModel, index: index)
                            }
                        }
                        .padding(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

private struct PhotoGalleryCell: View {
    let viewModel: PhotoGalleryViewModel
    let index: Int

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack {
            Color.white.opacity(0.08)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .onAppear {
            requestID = viewModel.requestThumbnail(
                at: index,
                targetSize: CGSize(width: 320, height: 320)
            ) { loadedImage in
                image = loadedImage
            }
        }
        .onDisappear {
            if let requestID {
                viewModel.cancelImageRequest(requestID)
            }
            requestID = nil
            image = nil
        }
    }
}

@MainActor
@Observable
final class PhotoGalleryViewModel: NSObject, PHPhotoLibraryChangeObserver {
    private(set) var assetCount = 0
    private(set) var isLoading = true
    private(set) var hasPhotoLibraryAccess = true

    @ObservationIgnored private var assets: PHFetchResult<PHAsset>?
    @ObservationIgnored private let imageManager = PHCachingImageManager()

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    var emptyStateDescription: String {
        hasPhotoLibraryAccess
            ? "There are no photos in your library."
            : "Allow photo access in Settings to browse your library."
    }

    func load() async {
        let authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            hasPhotoLibraryAccess = false
            isLoading = false
            return
        }

        loadAuthorizedAssets()
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self, hasPhotoLibraryAccess else { return }
            loadAuthorizedAssets()
        }
    }

    private func loadAuthorizedAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: false)
        ]
        let fetchedAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        assets = fetchedAssets
        assetCount = fetchedAssets.count
        hasPhotoLibraryAccess = true
        isLoading = false
    }

    func requestThumbnail(
        at index: Int,
        targetSize: CGSize,
        completion: @escaping @MainActor (UIImage?) -> Void
    ) -> PHImageRequestID? {
        guard let assets, index >= 0, index < assets.count else { return nil }

        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic
        requestOptions.resizeMode = .fast
        requestOptions.isNetworkAccessAllowed = true

        return imageManager.requestImage(
            for: assets.object(at: index),
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: requestOptions
        ) { image, _ in
            Task { @MainActor in
                completion(image)
            }
        }
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }
}
