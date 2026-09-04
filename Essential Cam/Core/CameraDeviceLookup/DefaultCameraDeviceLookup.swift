//
//  DefaultCameraDeviceLookup.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import AVFoundation

final class DefaultCameraDeviceLookup: CameraDeviceLookup {

    private static let backCameraTypes: [AVCaptureDevice.DeviceType] = [
        .builtInWideAngleCamera,
        .builtInUltraWideCamera,
        .builtInTelephotoCamera
    ]

    private static let frontCameraTypes: [AVCaptureDevice.DeviceType] = [
        .builtInWideAngleCamera
    ]

    private let backCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let frontCameraDiscoverySession: AVCaptureDevice.DiscoverySession

    init() {
        backCameraDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: Self.backCameraTypes,
            mediaType: .video,
            position: .back
        )

        frontCameraDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: Self.frontCameraTypes,
            mediaType: .video,
            position: .front
        )
    }

    var backCameras: [AVCaptureDevice] {
        backCameraDiscoverySession.devices
    }

    var frontCameras: [AVCaptureDevice] {
        frontCameraDiscoverySession.devices
    }

    var availableCameras: [AVCaptureDevice] {
        backCameras + frontCameras
    }

    var mainBackCamera: AVCaptureDevice? {
        backCameras.first {
            $0.deviceType == .builtInWideAngleCamera
        }
    }

    var mainFrontCamera: AVCaptureDevice? {
        frontCameras.first {
            $0.deviceType == .builtInWideAngleCamera
        }
    }
}
