//
//  CameraCaptureView.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

import SwiftUI

struct CameraCaptureView: View {
    let viewModel: CameraViewModel
    let showSettings: () -> Void
    let showGallery: () -> Void

    @State private var zoomFactorAtGestureStart: Double?
    @State private var displayedCapturePreview: CapturedPhotoPreview?
    @State private var isCapturePreviewFlyingToGallery = false

    var body: some View {
        GeometryReader { geometry in
            let previewContainerHeight = min(
                geometry.size.width * 16 / 9,
                geometry.size.height
            )
            let previewWidthToHeight = viewModel.controls.settings.aspectRatio.previewWidthToHeight
            let recentPhotoThumbnails = viewModel.recentPhotoThumbnails
            ZStack {
                VStack(spacing: .zero) {
                    ZStack {
                        Color.clear

                        CameraPreview(session: viewModel.captureSession)
                            .aspectRatio(previewWidthToHeight, contentMode: .fit)
                            .clipped()
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .center
                            )
                            .contentShape(Rectangle())
                            .gesture(zoomGesture)
                    }
                    .frame(width: geometry.size.width, height: previewContainerHeight)
                }

            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .trailing) {
                CameraControlsOverlayView(viewModel: viewModel)
            }
            .overlay(alignment: .topTrailing) {
                CameraFlashButton(controls: viewModel.controls)
                    .padding(8)
            }
            .overlay(alignment: .topLeading) {
                CameraSettingsButton(action: showSettings)
                    .padding(8)
            }
            .overlay(alignment: .bottom) {
                CaptureControlsView(
                    captureAction: viewModel.captureAction,
                    isCaptureDisabled: viewModel.isPerformingCaptureOperation
                )
                .padding(.bottom, 42)
            }
            .overlay(alignment: .bottomLeading) {
                Button(action: showGallery) {
                    GalleryThumbnailStack(thumbnails: recentPhotoThumbnails)
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.bottom, 48)
                .accessibilityLabel("Open Photo Library")
                .accessibilityHint("Shows your photos in a grid")
            }
            .overlay {
                if let displayedCapturePreview {
                    CapturedPhotoTransitionView(
                        preview: displayedCapturePreview,
                        containerSize: geometry.size,
                        previewContainerHeight: previewContainerHeight,
                        isFlyingToGallery: isCapturePreviewFlyingToGallery
                    )
                    .allowsHitTesting(false)
                }
            }
            .task(id: viewModel.capturedPhotoPreview?.id) {
                guard let preview = viewModel.capturedPhotoPreview else { return }

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    displayedCapturePreview = preview
                    isCapturePreviewFlyingToGallery = false
                }

                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.3)) {
                    isCapturePreviewFlyingToGallery = true
                }

                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled,
                      displayedCapturePreview?.id == preview.id else { return }
                displayedCapturePreview = nil
            }
        }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let startingZoomFactor = zoomFactorAtGestureStart
                    ?? viewModel.controls.settings.zoomFactor
                zoomFactorAtGestureStart = startingZoomFactor
                viewModel.controls.setZoomFactor(
                    startingZoomFactor * Double(value.magnification)
                )
            }
            .onEnded { _ in
                zoomFactorAtGestureStart = nil
            }
    }

}

private struct CapturedPhotoTransitionView: View {
    let preview: CapturedPhotoPreview
    let containerSize: CGSize
    let previewContainerHeight: CGFloat
    let isFlyingToGallery: Bool

    private var displayedSize: CGSize {
        if isFlyingToGallery {
            return thumbnailSize
        }

        let availableSize = CGSize(
            width: containerSize.width,
            height: previewContainerHeight
        )
        let availableAspectRatio = availableSize.width / availableSize.height

        if preview.aspectRatio > availableAspectRatio {
            return CGSize(
                width: availableSize.width,
                height: availableSize.width / preview.aspectRatio
            )
        }
        return CGSize(
            width: availableSize.height * preview.aspectRatio,
            height: availableSize.height
        )
    }

    private var thumbnailSize: CGSize {
        let maximumDimension: CGFloat = 48
        if preview.aspectRatio >= 1 {
            return CGSize(
                width: maximumDimension,
                height: maximumDimension / preview.aspectRatio
            )
        }
        return CGSize(
            width: maximumDimension * preview.aspectRatio,
            height: maximumDimension
        )
    }

    private var position: CGPoint {
        if isFlyingToGallery {
            // Matches the center of the 60-point gallery button with its padding.
            return CGPoint(x: 46, y: containerSize.height - 78)
        }
        return CGPoint(x: containerSize.width / 2, y: previewContainerHeight / 2)
    }

    var body: some View {
        Image(decorative: preview.image, scale: 1)
            .resizable()
            .scaledToFill()
            .frame(width: displayedSize.width, height: displayedSize.height)
            .clipShape(.rect(cornerRadius: isFlyingToGallery ? 5 : 0))
            .overlay {
                RoundedRectangle(cornerRadius: isFlyingToGallery ? 5 : 0)
                    .stroke(.white.opacity(isFlyingToGallery ? 0.9 : 0), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(isFlyingToGallery ? 0.45 : 0),
                radius: isFlyingToGallery ? 2 : 0,
                y: isFlyingToGallery ? 1 : 0
            )
            .position(position)
    }
}

private struct GalleryThumbnailStack: View {
    let thumbnails: [PhotoLibraryThumbnail]

    var body: some View {
        ZStack {
            if thumbnails.isEmpty {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                ForEach(Array(thumbnails.prefix(3).enumerated()).reversed(), id: \.element.id) { index, thumbnail in
                    GalleryThumbnailCard(thumbnail: thumbnail)
                        .rotationEffect(.degrees(rotation(for: index)))
                        .offset(x: offset(for: index).width, y: offset(for: index).height)
                        .zIndex(Double(3 - index))
                }
            }
        }
        .frame(width: 60, height: 60)
        .background {
            if thumbnails.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
        .contentShape(.rect(cornerRadius: 12))
    }

    private func rotation(for index: Int) -> Double {
        switch index {
        case 1: -6
        case 2: 6
        default: 0
        }
    }

    private func offset(for index: Int) -> CGSize {
        switch index {
        case 1: CGSize(width: -3, height: -2)
        case 2: CGSize(width: 3, height: -3)
        default: .zero
        }
    }
}

private struct GalleryThumbnailCard: View {
    let thumbnail: PhotoLibraryThumbnail

    private var size: CGSize {
        let maximumDimension: CGFloat = 48
        if thumbnail.aspectRatio >= 1 {
            return CGSize(
                width: maximumDimension,
                height: maximumDimension / thumbnail.aspectRatio
            )
        }
        return CGSize(
            width: maximumDimension * thumbnail.aspectRatio,
            height: maximumDimension
        )
    }

    var body: some View {
        Image(uiImage: thumbnail.image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipShape(.rect(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
    }
}
