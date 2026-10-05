//
//  LoadQuickSettingsUseCase.swift
//  Essential Cam
//
//  Created by Alexander López.
//

@MainActor
struct LoadQuickSettingsUseCase {
    let store: any QuickSettingsStoring
    let repository: any QuickSettingsRepository

    func execute() {
        guard let saved = repository.loadIdentifiers() else {
            store.included = QuickSettingControl.initialControls
            return
        }
        var seen = Set<String>()
        store.included = saved.compactMap { identifier in
            guard seen.insert(identifier).inserted else { return nil }
            guard let control = QuickSettingControl(rawValue: identifier),
                  QuickSettingControl.controls(for: store.captureMode).contains(control) else { return nil }
            return control
        }
    }
}
