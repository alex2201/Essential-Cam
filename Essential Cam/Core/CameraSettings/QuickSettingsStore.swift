//
//  QuickSettingsStore.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Observation

@MainActor
@Observable
final class QuickSettingsStore: QuickSettingsStoring {
    var captureMode = CaptureMode.photo
    private var photoIncluded: [QuickSettingControl] = []
    private var videoIncluded: [QuickSettingControl] = []
    var included: [QuickSettingControl] {
        get { captureMode == .photo ? photoIncluded : videoIncluded }
        set {
            if captureMode == .photo { photoIncluded = newValue } else { videoIncluded = newValue }
        }
    }
}
