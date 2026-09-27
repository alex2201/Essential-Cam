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
