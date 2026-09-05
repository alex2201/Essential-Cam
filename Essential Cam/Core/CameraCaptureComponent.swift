//
//  CameraCaptureComponent.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

import AVFoundation

protocol CameraCaptureComponent {
    var output: AVCaptureOutput { get }

    func updateConfiguration(for device: AVCaptureDevice)
    func setVideoRotationAngle(_ angle: CGFloat)
}

extension CameraCaptureComponent {
    func updateConfiguration(for device: AVCaptureDevice) {}

    func setVideoRotationAngle(_ angle: CGFloat) {
        output.connection(with: .video)?.videoRotationAngle = angle
    }
}
