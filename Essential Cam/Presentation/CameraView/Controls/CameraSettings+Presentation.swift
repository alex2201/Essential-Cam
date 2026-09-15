//
//  CameraSettings+Presentation.swift
//  Essential Cam
//

import Foundation

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

extension ExposureSetting {
    var displayName: String {
        switch self {
        case let .automatic(exposureBias):
            exposureBias.exposureBiasDisplayName
        case .manual:
            "MAN"
        }
    }

    var exposureBias: Float? {
        switch self {
        case let .automatic(exposureBias):
            exposureBias
        case .manual:
            nil
        }
    }

    func settingExposureBias(_ exposureBias: Float) -> ExposureSetting {
        switch self {
        case .automatic:
            .automatic(exposureBias: exposureBias)
        case .manual:
            .automatic(exposureBias: exposureBias)
        }
    }
}

extension FocusSetting {
    static let manualLensPositionOptions: [Float] = [0, 0.25, 0.5, 0.75, 1]

    var displayName: String {
        switch self {
        case .locked:
            "LOCK"
        case .auto:
            "AUTO"
        case .continuousAuto:
            "CONT"
        case let .manual(lensPosition):
            lensPosition.lensPositionDisplayName
        }
    }

    func hasLensPosition(_ lensPosition: Float) -> Bool {
        guard case let .manual(currentLensPosition) = self else {
            return false
        }

        return currentLensPosition == lensPosition
    }
}

extension Float {
    var exposureBiasDisplayName: String {
        let absoluteValue = String(format: "%.1f", abs(self))

        if self > 0 {
            return "+\(absoluteValue)"
        }

        if self < 0 {
            return "−\(absoluteValue)"
        }

        return absoluteValue
    }

    var lensPositionDisplayName: String {
        switch self {
        case 0:
            "NEAR"
        case 1:
            "FAR"
        default:
            "\(Int((self * 100).rounded()))%"
        }
    }
}
