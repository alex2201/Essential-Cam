//
//  CameraSettings.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
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
    var photoOutputFormat: PhotoOutputFormat = .heif
    var photoResolution: PhotoResolution?
    var photoTimer: PhotoTimer = .off
    var contentAwareCorrection: ContentAwareCorrection = .off
    var video: VideoSettings = .standard

    private enum CodingKeys: String, CodingKey {
        case exposure
        case focus
        case whiteBalance
        case zoomFactor
        case captureMode
        case aspectRatio
        case flashMode
        case photoOutputFormat
        case photoResolution
        case photoTimer
        case contentAwareCorrection
        case video
    }

    init(
        exposure: ExposureSetting,
        focus: FocusSetting,
        whiteBalance: WhiteBalanceSetting,
        zoomFactor: Double,
        captureMode: CaptureMode,
        aspectRatio: CameraAspectRatio,
        flashMode: CameraFlashMode,
        photoOutputFormat: PhotoOutputFormat = .heif,
        photoResolution: PhotoResolution? = nil,
        photoTimer: PhotoTimer = .off,
        contentAwareCorrection: ContentAwareCorrection = .off,
        video: VideoSettings = .standard
    ) {
        self.exposure = exposure
        self.focus = focus
        self.whiteBalance = whiteBalance
        self.zoomFactor = zoomFactor
        self.captureMode = captureMode
        self.aspectRatio = aspectRatio
        self.flashMode = flashMode
        self.photoOutputFormat = photoOutputFormat
        self.photoResolution = photoResolution
        self.photoTimer = photoTimer
        self.contentAwareCorrection = contentAwareCorrection
        self.video = video
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exposure = try container.decode(ExposureSetting.self, forKey: .exposure)
        focus = try container.decode(FocusSetting.self, forKey: .focus)
        whiteBalance = try container.decode(WhiteBalanceSetting.self, forKey: .whiteBalance)
        zoomFactor = try container.decode(Double.self, forKey: .zoomFactor)
        captureMode = try container.decode(CaptureMode.self, forKey: .captureMode)
        aspectRatio = try container.decode(CameraAspectRatio.self, forKey: .aspectRatio)
        flashMode = try container.decode(CameraFlashMode.self, forKey: .flashMode)
        photoOutputFormat = try container.decodeIfPresent(
            PhotoOutputFormat.self,
            forKey: .photoOutputFormat
        ) ?? .heif
        photoResolution = try container.decodeIfPresent(
            PhotoResolution.self,
            forKey: .photoResolution
        )
        photoTimer = try container.decodeIfPresent(PhotoTimer.self, forKey: .photoTimer) ?? .off
        contentAwareCorrection = try container.decodeIfPresent(
            ContentAwareCorrection.self,
            forKey: .contentAwareCorrection
        ) ?? .off
        video = try container.decodeIfPresent(VideoSettings.self, forKey: .video) ?? .standard
    }
}

extension CameraSettings {
    static func standard(for mode: CaptureMode) -> CameraSettings {
        var settings = standard
        settings.captureMode = mode
        if mode == .video { settings.aspectRatio = .sixteenByNine }
        return settings
    }

    static let standard = CameraSettings(
        exposure: .automatic(exposureBias: 0),
        focus: .continuousAuto,
        whiteBalance: .continuousAuto,
        zoomFactor: 1,
        captureMode: .photo,
        aspectRatio: .fourByThree,
        flashMode: .off,
        photoOutputFormat: .heif,
        photoResolution: nil,
        photoTimer: .off,
        contentAwareCorrection: .off
    )
}

enum ExposureSetting: Codable, Equatable, Sendable {
    case automatic(exposureBias: Float)
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

extension CameraAspectRatio {
    func widthToHeight(isPortrait: Bool) -> CGFloat {
        switch self {
        case .fourByThree:
            isPortrait ? 3 / 4 : 4 / 3
        case .sixteenByNine:
            isPortrait ? 9 / 16 : 16 / 9
        case .square:
            1
        }
    }
}

enum CameraFlashMode: String, Codable, Equatable, Sendable {
    case off
    case on
    case automatic
}

enum PhotoOutputFormat: String, Codable, Equatable, Sendable, CaseIterable {
    case heif
    case jpeg
    case png
    case tiff
    case raw
    case appleProRAW

    var isRAW: Bool {
        self == .raw || self == .appleProRAW
    }
}

struct PhotoResolution: Codable, Equatable, Hashable, Sendable {
    let width: Int32
    let height: Int32

    var megapixels: Double {
        Double(width) * Double(height) / 1_000_000
    }
}

enum PhotoTimer: Int, Codable, Equatable, Sendable, CaseIterable {
    case off = 0
    case threeSeconds = 3
    case fiveSeconds = 5
    case tenSeconds = 10

    var duration: Duration {
        .seconds(rawValue)
    }
}

enum ContentAwareCorrection: String, Codable, Equatable, Sendable, CaseIterable {
    case off
    case automatic
}
