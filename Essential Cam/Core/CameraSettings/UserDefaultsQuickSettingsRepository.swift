//
//  UserDefaultsQuickSettingsRepository.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Foundation

@MainActor
struct UserDefaultsQuickSettingsRepository: QuickSettingsRepository {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, mode: CaptureMode = .photo) {
        self.defaults = defaults
        key = mode == .photo ? "camera.quickSettings.v1" : "camera.videoQuickSettings.v1"
    }

    func loadIdentifiers() -> [String]? {
        defaults.stringArray(forKey: key)
    }

    func saveIdentifiers(_ identifiers: [String]) {
        defaults.set(identifiers, forKey: key)
    }
}
