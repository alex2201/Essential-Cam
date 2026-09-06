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
    private let virtualBackCameraDiscoverySession: AVCaptureDevice.DiscoverySession

    init() {
        virtualBackCameraDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera],
            mediaType: .video,
            position: .back
        )

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

    func displayZoomFactor(for device: AVCaptureDevice) -> Double? {
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return 0.5
        case .builtInWideAngleCamera:
            return 1
        case .builtInTelephotoCamera:
            for virtualCamera in virtualBackCameraDiscoverySession.devices {
                let lenses = virtualCamera.constituentDevices
                guard let lensIndex = lenses.firstIndex(where: { $0.uniqueID == device.uniqueID }),
                      let mainIndex = lenses.firstIndex(where: { $0.deviceType == .builtInWideAngleCamera }) else {
                    continue
                }

                // These factors use the virtual camera's scale. Normalize to main = 1×.
                let factors = [1.0] + virtualCamera.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue)
                guard factors.count == lenses.count, factors[mainIndex] > 0 else {
                    continue
                }
                return factors[lensIndex] / factors[mainIndex]
            }
            return nil
        default:
            return nil
        }
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
