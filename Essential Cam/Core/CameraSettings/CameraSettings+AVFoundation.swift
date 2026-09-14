//
//  CameraSettings+AVFoundation.swift
//  Essential Cam
//

import AVFoundation

enum CaptureExposureConfiguration {
    case mode(AVCaptureDevice.ExposureMode, exposureBias: Float?)
    case manual(iso: Float, duration: CMTime)
}

enum CaptureFocusConfiguration {
    case mode(AVCaptureDevice.FocusMode)
    case manual(lensPosition: Float)
}

enum CaptureWhiteBalanceConfiguration {
    case mode(AVCaptureDevice.WhiteBalanceMode)
    case manual(AVCaptureDevice.WhiteBalanceTemperatureAndTintValues)
}

extension ExposureSetting {
    var avFoundationConfiguration: CaptureExposureConfiguration {
        switch self {
        case .locked:
            .mode(.locked, exposureBias: nil)
        case let .auto(exposureBias):
            .mode(.autoExpose, exposureBias: exposureBias)
        case let .continuousAuto(exposureBias):
            .mode(.continuousAutoExposure, exposureBias: exposureBias)
        case let .manual(iso, durationInSeconds):
            .manual(
                iso: iso,
                duration: CMTime(
                    seconds: durationInSeconds,
                    preferredTimescale: 1_000_000_000
                )
            )
        }
    }
}

extension FocusSetting {
    var avFoundationConfiguration: CaptureFocusConfiguration {
        switch self {
        case .locked:
            .mode(.locked)
        case .auto:
            .mode(.autoFocus)
        case .continuousAuto:
            .mode(.continuousAutoFocus)
        case let .manual(lensPosition):
            .manual(lensPosition: lensPosition)
        }
    }
}

extension WhiteBalanceSetting {
    var avFoundationConfiguration: CaptureWhiteBalanceConfiguration {
        switch self {
        case .locked:
            .mode(.locked)
        case .auto:
            .mode(.autoWhiteBalance)
        case .continuousAuto:
            .mode(.continuousAutoWhiteBalance)
        case let .manual(temperature, tint):
            .manual(
                .init(
                    temperature: temperature,
                    tint: tint
                )
            )
        }
    }
}

extension CameraFlashMode {
    var avFoundationValue: AVCaptureDevice.FlashMode {
        switch self {
        case .off:
            .off
        case .on:
            .on
        case .automatic:
            .auto
        }
    }
}

extension CameraSettings {
    var avFoundationZoomFactor: CGFloat {
        CGFloat(zoomFactor)
    }
}

@available(iOS 26.0, *)
extension CameraAspectRatio {
    func avFoundationValue(
        for orientation: CaptureOrientation
    ) -> AVCaptureDevice.AspectRatio {
        switch (self, orientation.isPortrait) {
        case (.fourByThree, true):
            .ratio3x4
        case (.fourByThree, false):
            .ratio4x3
        case (.sixteenByNine, true):
            .ratio9x16
        case (.sixteenByNine, false):
            .ratio16x9
        case (.square, _):
            .ratio1x1
        }
    }
}
