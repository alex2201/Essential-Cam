//
//  CaptureOrientation.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

enum CaptureOrientation: Equatable, Sendable {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
}

extension CaptureOrientation {
    var isPortrait: Bool {
        switch self {
        case .portrait, .portraitUpsideDown:
            true
        case .landscapeLeft, .landscapeRight:
            false
        }
    }
}
