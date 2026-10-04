// Presentation preferences stay independent of camera values and presets.
enum QuickSettingControl: String, CaseIterable, Identifiable {
    case aspectRatio, photoTimer, photoResolution, exposure, focus, whiteBalance

    static let initialControls: [Self] = [.exposure, .focus, .whiteBalance]

    var id: String { rawValue }

}
