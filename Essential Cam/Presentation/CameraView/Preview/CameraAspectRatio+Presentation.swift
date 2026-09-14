//
//  CameraAspectRatio+Presentation.swift
//  Essential Cam
//

import SwiftUI

extension CameraAspectRatio {
    static var allCases: [CameraAspectRatio] {
        [.fourByThree, .sixteenByNine, .square]
    }

    var displayName: String {
        switch self {
        case .fourByThree:
            "4:3"
        case .sixteenByNine:
            "16:9"
        case .square:
            "1:1"
        }
    }

    var previewWidthToHeight: CGFloat {
        switch self {
        case .fourByThree:
            3 / 4
        case .sixteenByNine:
            9 / 16
        case .square:
            1
        }
    }
}
