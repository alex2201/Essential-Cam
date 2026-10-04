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
    var isVideoMode = false

    func makeUIView(context: Context) -> PreviewView {
        let previewView = PreviewView()
        previewView.previewLayer.session = session
        previewView.isVideoMode = isVideoMode
        previewView.previewLayer.videoGravity = .resizeAspectFill
        return previewView
    }

    func updateUIView(_ previewView: PreviewView, context: Context) {
        previewView.isVideoMode = isVideoMode
        previewView.setNeedsLayout()
    }
}

extension CameraPreview {
    final class PreviewView: UIView {
        private let contentView = PreviewContentView()
        var isVideoMode = false

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
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor(white: 0.18, alpha: 1).cgColor,
                UIColor(white: 0.04, alpha: 1).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0.15, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0.85, y: 1)
            contentView.layer.addSublayer(gradientLayer)
            simulatorGradientLayer = gradientLayer

            let symbolView = UIImageView(image: UIImage(systemName: "camera.aperture"))
            symbolView.translatesAutoresizingMaskIntoConstraints = false
            symbolView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
                pointSize: 42,
                weight: .ultraLight
            )
            symbolView.tintColor = UIColor.white.withAlphaComponent(0.16)
            contentView.addSubview(symbolView)

            NSLayoutConstraint.activate([
                symbolView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                symbolView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
#endif
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if isVideoMode, let connection = previewLayer.connection {
                let angle: CGFloat = 90
                if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            }
#if targetEnvironment(simulator)
            simulatorGradientLayer?.frame = contentView.bounds
#endif
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            contentView.previewLayer
        }

#if targetEnvironment(simulator)
        private var simulatorGradientLayer: CAGradientLayer?
#endif
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
