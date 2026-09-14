//
//  CameraPreview.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

@preconcurrency import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let previewView = PreviewView()
        previewView.previewLayer.session = session
        previewView.previewLayer.videoGravity = .resizeAspectFill
        return previewView
    }

    func updateUIView(_ previewView: PreviewView, context: Context) {
        // No-op.
    }
}

extension CameraPreview {
    final class PreviewView: UIView {
        private let contentView = PreviewContentView()

        init() {
            super.init(frame: .zero)

            contentView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(contentView)

            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                contentView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
                contentView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
                contentView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor)
            ])

#if targetEnvironment(simulator)
            // The capture APIs require running on a real device. If running
            // in Simulator, display a static image to represent the video feed.
            let imageView = UIImageView()
            // TODO: Add asset for simulator
            //            imageView.image = UIImage(named: "video_mode")
            imageView.contentMode = .scaleAspectFill
            // The image view resizes to fill the preview area.
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            contentView.addSubview(imageView)
#endif
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            contentView.previewLayer
        }
    }

    final class PreviewContentView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
