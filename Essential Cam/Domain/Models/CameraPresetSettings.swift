//
//  CameraPresetSettings.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Foundation

struct CameraPreset: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var settings: CameraPresetSettings
    var captureMode: CaptureMode { settings.captureMode }

    init(
        id: UUID = UUID(),
        name: String,
        settings: CameraPresetSettings
    ) {
        self.id = id
        self.name = name
        self.settings = settings
    }
}

struct CameraPresetSettings: Codable, Equatable, Sendable {
    var captureMode: CaptureMode = .photo
    var photoOutputFormat: PhotoOutputFormat?
    var photoResolution: PhotoResolution?
    var photoTimer: PhotoTimer?
    var contentAwareCorrection: ContentAwareCorrection?
    var video: VideoSettings?
    var exposure: ExposureSetting?
    var focus: FocusSetting?
    var whiteBalance: WhiteBalanceSetting?
    var aspectRatio: CameraAspectRatio?
    var flashMode: CameraFlashMode?

    init(
        captureMode: CaptureMode = .photo,
        exposure: ExposureSetting? = nil,
        focus: FocusSetting? = nil,
        whiteBalance: WhiteBalanceSetting? = nil,
        aspectRatio: CameraAspectRatio? = nil,
        flashMode: CameraFlashMode? = nil
    ) {
        self.captureMode = captureMode
        self.exposure = exposure
        self.focus = focus
        self.whiteBalance = whiteBalance
        self.aspectRatio = aspectRatio
        self.flashMode = flashMode
    }

    init(settings: CameraSettings) {
        captureMode = settings.captureMode
        photoOutputFormat = settings.photoOutputFormat
        photoResolution = settings.photoResolution
        photoTimer = settings.photoTimer
        contentAwareCorrection = settings.contentAwareCorrection
        video = settings.captureMode == .video ? settings.video : nil
        exposure = settings.exposure
        focus = settings.focus.presetValue
        whiteBalance = settings.whiteBalance.presetValue
        aspectRatio = settings.aspectRatio
        flashMode = settings.flashMode
    }
    private enum CodingKeys: String, CodingKey {
        case captureMode, exposure, focus, whiteBalance, aspectRatio, flashMode
        case photoOutputFormat, photoResolution, photoTimer, contentAwareCorrection, video
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        captureMode = try values.decodeIfPresent(CaptureMode.self, forKey: .captureMode) ?? .photo
        exposure = try values.decodeIfPresent(ExposureSetting.self, forKey: .exposure)
        focus = try values.decodeIfPresent(FocusSetting.self, forKey: .focus)
        whiteBalance = try values.decodeIfPresent(WhiteBalanceSetting.self, forKey: .whiteBalance)
        aspectRatio = try values.decodeIfPresent(CameraAspectRatio.self, forKey: .aspectRatio)
        flashMode = try values.decodeIfPresent(CameraFlashMode.self, forKey: .flashMode)
        photoOutputFormat = try values.decodeIfPresent(PhotoOutputFormat.self, forKey: .photoOutputFormat)
        photoResolution = try values.decodeIfPresent(PhotoResolution.self, forKey: .photoResolution)
        photoTimer = try values.decodeIfPresent(PhotoTimer.self, forKey: .photoTimer)
        contentAwareCorrection = try values.decodeIfPresent(ContentAwareCorrection.self, forKey: .contentAwareCorrection)
        video = try values.decodeIfPresent(VideoSettings.self, forKey: .video)
    }

    func applying(to current: CameraSettings) -> CameraSettings {
        guard current.captureMode == captureMode else { return current }
        let defaults = CameraSettings.standard(for: captureMode)
        var result = current
        result.exposure = exposure ?? defaults.exposure
        result.focus = focus ?? defaults.focus
        result.whiteBalance = whiteBalance ?? defaults.whiteBalance
        if captureMode == .photo {
            result.aspectRatio = aspectRatio ?? defaults.aspectRatio
            result.flashMode = flashMode ?? defaults.flashMode
            // Missing fields in legacy presets retain their original behavior.
            result.photoOutputFormat = photoOutputFormat ?? current.photoOutputFormat
            result.photoResolution = photoResolution ?? current.photoResolution
            result.photoTimer = photoTimer ?? current.photoTimer
            result.contentAwareCorrection = contentAwareCorrection ?? current.contentAwareCorrection
        } else {
            result.video = video ?? .standard
        }
        return result
    }
}

private extension FocusSetting {
    var presetValue: Self? {
        self == .locked ? nil : self
    }
}

private extension WhiteBalanceSetting {
    var presetValue: Self? {
        self == .locked ? nil : self
    }
}
