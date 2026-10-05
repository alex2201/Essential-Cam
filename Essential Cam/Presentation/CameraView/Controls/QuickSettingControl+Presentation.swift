//
//  QuickSettingControl+Presentation.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Foundation

extension QuickSettingControl {
    var title: String {
        switch self {
        case .aspectRatio: "Aspect Ratio"
        case .photoTimer: "Timer"
        case .photoResolution: "Photo Resolution"
        case .exposure: "Exposure"
        case .focus: "Focus"
        case .whiteBalance: "White Balance"
        case .videoResolution: "Video Resolution"
        case .videoFrameRate: "Frame Rate"
        case .videoCodec: "Video Codec"
        case .videoStabilization: "Stabilization"
        case .videoTorch: "Continuous Light"
        case .videoMicrophone: "Microphone"
        }
    }
}

