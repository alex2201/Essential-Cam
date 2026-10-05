//
//  QuickSettingControl.swift
//  Essential Cam
//
//  Created by Alexander López.
//

// Presentation preferences stay independent of camera values and presets.
enum QuickSettingControl: String, CaseIterable, Identifiable {
    case aspectRatio, photoTimer, photoResolution, exposure, focus, whiteBalance
    case videoResolution, videoFrameRate, videoCodec, videoStabilization, videoTorch, videoMicrophone

    static let initialControls: [Self] = [.exposure, .focus, .whiteBalance]
    static func controls(for mode: CaptureMode) -> [Self] {
        allCases.filter { control in
            switch control {
            case .exposure, .focus, .whiteBalance: true
            case .aspectRatio, .photoTimer, .photoResolution: mode == .photo
            default: mode == .video
            }
        }
    }
    var id: String { rawValue }
}
