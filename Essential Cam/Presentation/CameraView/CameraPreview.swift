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
        previewView.previewLayer.videoGravity = .resizeAspect
        return previewView
    }

    func updateUIView(_ previewView: PreviewView, context: Context) {
        // No-op.
    }
}

extension CameraPreview {
    final class PreviewView: UIView {

        init() {
            super.init(frame: .zero)
#if targetEnvironment(simulator)
            // The capture APIs require running on a real device. If running
            // in Simulator, display a static image to represent the video feed.
            let imageView = UIImageView()
            // TODO: Add asset for simulator
            //            imageView.image = UIImage(named: "video_mode")
            imageView.contentMode = .scaleAspectFill
            // The image view resizes to fill the preview area.
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(imageView)
#endif
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // Use the preview layer as the view's backing layer.
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
