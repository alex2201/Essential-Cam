//
//  VideoSettings+Presentation.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Foundation

extension VideoResolution {
    var displayName: String { self == .fullHD ? "1080p" : "4K" }
}
extension VideoFrameRate {
    var displayName: String { "\(rawValue) fps" }
}
extension VideoCodec {
    var displayName: String { self == .h264 ? "H.264 (Compatible)" : "HEVC (Smaller Files)" }
    var shortName: String { self == .h264 ? "H.264" : "HEVC" }
}
extension VideoStabilization {
    var displayName: String {
        switch self {
        case .off: "Off"
        case .standard: "Standard"
        case .cinematic: "Cinematic"
        case .cinematicExtended: "Extended Cinematic"
        }
    }
}


extension VideoMicrophoneSelection {
    var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .iPhone: "iPhone Microphone"
        case let .external(_, name): name
        }
    }
}
