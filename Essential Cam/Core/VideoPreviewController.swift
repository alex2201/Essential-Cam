//
//  VideoPreviewController.swift
//  Essential Cam
//
//  Created by Alexander López on 02/09/26.
//

@preconcurrency import AVFoundation

protocol VideoPreviewController {
    func attach(to previewLayer: AVCaptureVideoPreviewLayer)
    func configureRotation(
        for device: AVCaptureDevice,
        captureRotationHandler: @escaping @Sendable (CGFloat) -> Void
    )
}

@MainActor
final class DefaultVideoPreviewController: VideoPreviewController {
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservers = [NSKeyValueObservation]()

    func attach(to previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
    }

    func configureRotation(
        for device: AVCaptureDevice,
        captureRotationHandler: @escaping @Sendable (CGFloat) -> Void
    ) {
        guard let previewLayer else {
            fatalError("A preview layer must be attached before configuring rotation.")
        }

        let rotationCoordinator = AVCaptureDevice.RotationCoordinator(
            device: device,
            previewLayer: previewLayer
        )
        self.rotationCoordinator = rotationCoordinator

        updatePreviewRotation(rotationCoordinator.videoRotationAngleForHorizonLevelPreview)
        captureRotationHandler(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)

        rotationObservers.removeAll()

        rotationObservers.append(
            rotationCoordinator.observe(
                \.videoRotationAngleForHorizonLevelPreview,
                 options: .new
            ) { [weak self] _, change in
                guard let angle = change.newValue else { return }

                Task { @MainActor [weak self] in
                    self?.updatePreviewRotation(angle)
                }
            }
        )

        rotationObservers.append(
            rotationCoordinator.observe(
                \.videoRotationAngleForHorizonLevelCapture,
                 options: .new
            ) { _, change in
                guard let angle = change.newValue else { return }
                captureRotationHandler(angle)
            }
        )
    }

    private func updatePreviewRotation(_ angle: CGFloat) {
        previewLayer?.connection?.videoRotationAngle = angle
    }
}
