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
        }
    }
}

