//
//  CustomizeQuickSettingsUseCase.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Foundation

@MainActor
struct CustomizeQuickSettingsUseCase {
    let store: any QuickSettingsStoring

    let repository: any QuickSettingsRepository

    init(store: any QuickSettingsStoring, repository: any QuickSettingsRepository) {
        self.store = store
        self.repository = repository
    }

    enum Action {
        case add(QuickSettingControl)
        case remove(QuickSettingControl)
        case move(IndexSet, destination: Int)
        case reset
    }

    var available: [QuickSettingControl] {
        QuickSettingControl.controls(for: store.captureMode).filter { !store.included.contains($0) }
    }

    func execute(_ action: Action) {
        var result = store.included
        switch action {
        case let .add(control):
            guard QuickSettingControl.controls(for: store.captureMode).contains(control), !result.contains(control) else { return }
            result.append(control)
        case let .remove(control):
            result.removeAll { $0 == control }
        case let .move(offsets, destination):
            guard (0...result.count).contains(destination),
                  offsets.allSatisfy({ result.indices.contains($0) }) else { return }
            let moving = offsets.sorted().map { result[$0] }
            let insertion = destination - offsets.filter { $0 < destination }.count
            for index in offsets.sorted(by: >) { result.remove(at: index) }
            result.insert(contentsOf: moving, at: insertion)
        case .reset:
            result = QuickSettingControl.initialControls
        }
        guard result != store.included else { return }
        repository.saveIdentifiers(result.map(\.rawValue))
        store.included = result
    }
}
