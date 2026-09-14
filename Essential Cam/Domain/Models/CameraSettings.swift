//
//  CameraSettings.swift
//  Essential Cam
//

import Foundation

struct CameraSettings: Codable, Equatable, Sendable {
    var exposure: ExposureSetting
    var focus: FocusSetting
    var whiteBalance: WhiteBalanceSetting
    var zoomFactor: Double
    var captureMode: CaptureMode
    var aspectRatio: CameraAspectRatio
    var flashMode: CameraFlashMode
}

extension CameraSettings {
    static let standard = CameraSettings(
        exposure: .continuousAuto(exposureBias: 0),
        focus: .continuousAuto,
        whiteBalance: .continuousAuto,
        zoomFactor: 1,
        captureMode: .photo,
        aspectRatio: .fourByThree,
        flashMode: .off
    )
}

enum ExposureSetting: Codable, Equatable, Sendable {
    case locked
    case auto(exposureBias: Float)
    case continuousAuto(exposureBias: Float)
    case manual(iso: Float, durationInSeconds: Double)
}

enum FocusSetting: Codable, Equatable, Sendable {
    case locked
    case auto
    case continuousAuto
    case manual(lensPosition: Float)
}

enum WhiteBalanceSetting: Codable, Equatable, Sendable {
    case locked
    case auto
    case continuousAuto
    case manual(temperature: Float, tint: Float)
}

enum CaptureMode: String, Codable, Equatable, Sendable {
    case photo
    case video
}

enum CameraAspectRatio: String, Codable, Equatable, Sendable {
    case fourByThree
    case sixteenByNine
    case square
}

enum CameraFlashMode: String, Codable, Equatable, Sendable {
    case off
    case on
    case automatic
}
