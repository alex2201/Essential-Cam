//
//  PreviewView.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation
import UIKit

class PreviewView: UIView {

    // Use `AVCaptureVideoPreviewLayer` as the view's backing layer.
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func setSession(_ session: AVCaptureSession) {
        // Connects the session with the preview layer, which allows the layer
        // to provide a live view of the captured content.
        previewLayer.session = session
    }
}
