//
//  CameraCaptureView.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

import SwiftUI

struct CameraCaptureView: View {
    @Environment(CameraPresetStore.self) private var presetStore

    let viewModel: CameraViewModel
    var iconOrientation: CaptureOrientation? = nil
    let showSettings: () -> Void
    let showGallery: () -> Void

    @State private var isFlashOptionsPresented = false
    @State private var zoomFactorAtGestureStart: Double?
    @State private var displayedCapturePreview: CapturedPhotoPreview?
    @State private var isCapturePreviewFlyingToGallery = false
    @State private var displayedCaptureMode: CaptureMode = .photo
    @State private var captureIndicatorScale: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let previewContainerHeight = min(
                geometry.size.width * 16 / 9,
                geometry.size.height
            )
            let previewWidthToHeight = viewModel.selectedCaptureMode == .video
                ? (geometry.size.width > geometry.size.height ? 16.0 / 9 : 9.0 / 16)
                : viewModel.controls.settings.aspectRatio.previewWidthToHeight
            let recentPhotoThumbnails = viewModel.recentPhotoThumbnails
            ZStack {
                VStack(spacing: .zero) {
                    ZStack {
                        Color.clear

                        CameraPreview(session: viewModel.captureSession, isVideoMode: viewModel.selectedCaptureMode == .video)
                            .aspectRatio(previewWidthToHeight, contentMode: .fit)
                            .clipped()
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .center
                            )
                            .contentShape(Rectangle())
                            .gesture(zoomGesture)
                            .allowsHitTesting(!viewModel.isCameraInteractionDisabled)

                    }
                    .frame(width: geometry.size.width, height: previewContainerHeight)
                }

            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .trailing) {
                CameraControlsOverlayView(viewModel: viewModel)
                    .allowsHitTesting(!viewModel.isCameraInteractionDisabled)
            }
            .overlay(alignment: .topLeading) {
                CameraSettingsButton(action: showSettings)
                    .disabled(viewModel.isCameraInteractionDisabled)
                    .padding(8)
            }
            .overlay(alignment: .top) {
                if let startedAt = viewModel.recordingStartedAt {
                    TimelineView(.periodic(from: startedAt, by: 1)) { context in
                        let seconds = max(0, Int(context.date.timeIntervalSince(startedAt)))
                        Label {
                            Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        } icon: {
                            Image(systemName: "record.circle.fill")
                        }
                            .font(.body.monospacedDigit().weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .cameraControlContentRotation()
                            .frame(width: 100, height: 44)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.red.opacity(0.85), in: .capsule)
                            .accessibilityLabel("Recording duration")
                            .accessibilityValue("\(seconds) seconds")
                    }
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) {
                CameraPresetCarouselView(
                    store: presetStore,
                    controls: viewModel.controls
                )
                .padding(.top, 8)
                .disabled(viewModel.isCameraInteractionDisabled)
                .id(viewModel.selectedCaptureMode)
                .allowsHitTesting(!viewModel.isCameraInteractionDisabled)
                .opacity(viewModel.isVideoCaptureInProgress ? 0 : 1)
                .accessibilityHidden(viewModel.isVideoCaptureInProgress)
            }
            .overlay(alignment: .center) {
                if let notice = viewModel.controls.configurationNotice {
                    VStack(spacing: 8) {
                        Text(notice).font(.footnote).multilineTextAlignment(.center)
                        Button("OK") { viewModel.controls.clearConfigurationNotice() }
                    }
                    .cameraControlContentRotation()
                    .padding()
                    .background(.regularMaterial, in: .rect(cornerRadius: 12))
                    .padding(40)
                }
            }
            .overlay(alignment: .bottom) {
                Group {
                    switch displayedCaptureMode {
                    case .photo:
                        CaptureControlsView(
                            captureAction: viewModel.captureAction,
                            isCaptureDisabled: viewModel.isCameraInteractionDisabled,
                            indicatorScale: captureIndicatorScale
                        )
                    case .video:
                        VideoCaptureControlsView(
                            recordAction: viewModel.recordVideoAction,
                            isRecording: viewModel.isRecordingVideo,
                            isBusy: viewModel.isVideoCaptureInProgress && !viewModel.isRecordingVideo,
                            indicatorScale: captureIndicatorScale
                        )
                        .disabled(viewModel.isVideoRecordDisabled)
                    }
                }
                .padding(.bottom, 42)
                .task(id: viewModel.selectedCaptureMode) {
                    await animateCaptureButton(to: viewModel.selectedCaptureMode)
                }
            }
            .overlay(alignment: .bottomLeading) {
                Button(action: showGallery) {
                    GalleryThumbnailStack(thumbnails: recentPhotoThumbnails)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isCameraInteractionDisabled)
                .padding(.leading, 16)
                .padding(.bottom, 16)
                .accessibilityLabel("Open Photo Library")
                .accessibilityValue(recentPhotoThumbnails.first?.isVideo == true ? "Latest capture: Video" : "Latest capture: Photo")
                .accessibilityHint("Shows your photos and videos in a grid")
            }
            .overlay(alignment: .bottomTrailing) {
                CaptureModeButton(selectedMode: Binding(
                    get: { viewModel.selectedCaptureMode },
                    set: { mode in
                        Task {
                            await viewModel.selectCaptureMode(mode)
#if !targetEnvironment(simulator)
                            await viewModel.checkVideoPermissions()
#endif
                        }
                    }
                ))
                    .disabled(viewModel.isCheckingVideoPermissions || viewModel.isCameraInteractionDisabled)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }
            .overlay {
                if let countdown = viewModel.captureCountdown {
                    Text(countdown.formatted())
                        .font(.system(size: 96, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .cameraIconRotation()
                        .shadow(color: .black.opacity(0.65), radius: 8)
                        .allowsHitTesting(false)
                        .accessibilityLabel("Photo in \(countdown) seconds")
                }
            }
            .overlay {
                if let displayedCapturePreview {
                    CapturedPhotoTransitionView(
                        preview: displayedCapturePreview,
                        containerSize: geometry.size,
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
        .overlay {
            if isFlashOptionsPresented {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { isFlashOptionsPresented = false }
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.selectedCaptureMode == .photo {
                CameraFlashButton(controls: viewModel.controls, isExpanded: $isFlashOptionsPresented)
                    .padding(8)
                    .disabled(viewModel.isCameraInteractionDisabled)
            }
        }
        .onChange(of: viewModel.isCameraInteractionDisabled) { _, disabled in
            if disabled { isFlashOptionsPresented = false }
        }
        .onChange(of: viewModel.selectedCaptureMode) { _, _ in
            isFlashOptionsPresented = false
        }
        .onDisappear { isFlashOptionsPresented = false }
        .environment(\.cameraIconRotationDegrees, iconOrientation?.controlRotationDegrees ?? 0)
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

    @MainActor
    private func animateCaptureButton(to mode: CaptureMode) async {
        guard displayedCaptureMode != mode else { return }

        withAnimation(.easeIn(duration: 0.14)) {
            captureIndicatorScale = 0.08
        }

        try? await Task.sleep(for: .milliseconds(140))
        guard !Task.isCancelled else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedCaptureMode = mode
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            captureIndicatorScale = 1
        }
    }

}

private struct CapturedPhotoTransitionView: View {
    let preview: CapturedPhotoPreview
    let containerSize: CGSize
    let isFlyingToGallery: Bool

    private var displayedSize: CGSize {
        if isFlyingToGallery {
            return thumbnailSize
        }
        let maximumDimension: CGFloat = 100
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
            return CGPoint(x: 46, y: containerSize.height - 46)
        }
        // Centers the preview in a 100-point container that shares the
        // gallery button's 16-point leading and bottom padding.
        return CGPoint(x: 66, y: containerSize.height - 66)
    }

    var body: some View {
        Image(decorative: preview.image, scale: 1)
            .resizable()
            .scaledToFill()
            .frame(width: displayedSize.width, height: displayedSize.height)
            .clipShape(.rect(cornerRadius: isFlyingToGallery ? 5 : 9))
            .overlay {
                RoundedRectangle(cornerRadius: isFlyingToGallery ? 5 : 9)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(0.45),
                radius: isFlyingToGallery ? 2 : 5,
                y: isFlyingToGallery ? 1 : 3
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
                    .cameraIconRotation()
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
            .overlay {
                if thumbnail.isVideo {
                    Image(systemName: "play.circle.fill")
                        .cameraIconRotation()
                        .font(.system(size: 18))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                        .accessibilityHidden(true)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
    }
}
