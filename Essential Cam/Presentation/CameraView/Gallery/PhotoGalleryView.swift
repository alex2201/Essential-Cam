//
//  PhotoGalleryView.swift
//  Essential Cam
//
//  Created by Codex on 27/09/26.
//

import AVKit
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
                        "No Photos or Videos",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text(viewModel.emptyStateDescription)
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(0..<viewModel.assetCount, id: \.self) { index in
                                PhotoGalleryCell(viewModel: viewModel, index: index)
                                    .id(viewModel.assetIdentifier(at: index))
                            }
                        }
                        .padding(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("Gallery")
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
    @State private var videoRequestID: PHImageRequestID?
    @State private var playback: GalleryVideoPlayback?
    @State private var isLoadingVideo = false
    @State private var playbackFailed = false

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
        .overlay {
            if viewModel.isVideo(at: index) {
                Button {
                    isLoadingVideo = true
                    videoRequestID = viewModel.requestVideo(at: index) { result in
                        isLoadingVideo = false
                        videoRequestID = nil
                        playback = result
                        playbackFailed = result == nil
                    }
                } label: {
                    if isLoadingVideo {
                        ProgressView().tint(.white)
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 36))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.6))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingVideo)
                .accessibilityLabel("Play video")
                .accessibilityHint("Opens the video player")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(viewModel.isVideo(at: index) ? "Video thumbnail" : "Photo thumbnail")
        .sheet(item: $playback) { GalleryVideoPlayerView(playback: $0) }
        .alert("Video Unavailable", isPresented: $playbackFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The video couldn't be loaded. Check your connection and Photos access, then try again.")
        }
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
            if let videoRequestID { viewModel.cancelImageRequest(videoRequestID) }
            videoRequestID = nil
            isLoadingVideo = false
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
            ? "There are no photos or videos in your library."
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
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        let fetchedAssets = PHAsset.fetchAssets(with: fetchOptions)
        assets = fetchedAssets
        assetCount = fetchedAssets.count
        hasPhotoLibraryAccess = true
        isLoading = false
    }

    func assetIdentifier(at index: Int) -> String {
        guard let assets, index >= 0, index < assets.count else { return "" }
        return assets.object(at: index).localIdentifier
    }

    func isVideo(at index: Int) -> Bool {
        guard let assets, index >= 0, index < assets.count else { return false }
        return assets.object(at: index).mediaType == .video
    }

    func requestVideo(at index: Int, completion: @escaping @MainActor (GalleryVideoPlayback?) -> Void) -> PHImageRequestID? {
        guard let assets, index >= 0, index < assets.count else { return nil }
        let asset = assets.object(at: index)
        let identifier = asset.localIdentifier
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        return imageManager.requestPlayerItem(forVideo: asset, options: options) { item, _ in
            Task { @MainActor in
                completion(item.map { GalleryVideoPlayback(id: identifier, player: AVPlayer(playerItem: $0)) })
            }
        }
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
