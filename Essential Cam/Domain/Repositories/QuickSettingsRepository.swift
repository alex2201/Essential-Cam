//
//  QuickSettingsRepository.swift
//  Essential Cam
//
//  Created by Alexander López.
//

// Persistence boundary shared by loading and customization use cases.
@MainActor
protocol QuickSettingsRepository {
    func loadIdentifiers() -> [String]?
    func saveIdentifiers(_ identifiers: [String])
}

@MainActor
protocol QuickSettingsStoring: AnyObject {
    var captureMode: CaptureMode { get }
    var included: [QuickSettingControl] { get set }
}
