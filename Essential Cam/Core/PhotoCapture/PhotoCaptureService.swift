//
//  PhotoCaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation

protocol PhotoCaptureService: CameraCaptureComponent {
    func capturePhoto() async throws -> Photo
}
