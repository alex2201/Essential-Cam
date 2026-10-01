import Foundation

struct CameraPreset: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var settings: CameraPresetSettings

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
    var exposure: ExposureSetting?
    var focus: FocusSetting?
    var whiteBalance: WhiteBalanceSetting?
    var aspectRatio: CameraAspectRatio?
    var flashMode: CameraFlashMode?

    init(
        exposure: ExposureSetting? = nil,
        focus: FocusSetting? = nil,
        whiteBalance: WhiteBalanceSetting? = nil,
        aspectRatio: CameraAspectRatio? = nil,
        flashMode: CameraFlashMode? = nil
    ) {
        self.exposure = exposure
        self.focus = focus
        self.whiteBalance = whiteBalance
        self.aspectRatio = aspectRatio
        self.flashMode = flashMode
    }

    init(settings: CameraSettings) {
        exposure = settings.exposure
        focus = settings.focus.presetValue
        whiteBalance = settings.whiteBalance.presetValue
        aspectRatio = settings.aspectRatio
        flashMode = settings.flashMode
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
