//
//  PhotoCapture.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation

protocol PhotoCapture {
    var output: AVCapturePhotoOutput { get }

    func capturePhoto() async throws -> Photo
    func updateConfiguration(for device: AVCaptureDevice)
    func setVideoRotationAngle(_ angle: CGFloat)
}

extension PhotoCapture {
    func setVideoRotationAngle(_ angle: CGFloat) {
        // Set the rotation angle on the output object's video connection.
        output.connection(with: .video)?.videoRotationAngle = angle
    }
    func updateConfiguration(for device: AVCaptureDevice) {}
}
