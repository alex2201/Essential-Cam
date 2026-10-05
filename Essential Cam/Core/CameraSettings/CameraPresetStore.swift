//
//  CameraPresetStore.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Foundation
import Observation

@MainActor
@Observable
final class CameraPresetStore: CameraPresetsLoading {
    private(set) var presets: [CameraPreset]
    private(set) var captureMode = CaptureMode.photo
    private var selections: [CaptureMode: CameraPreset.ID] = [:]
    private var manualProfiles = CaptureSettingsProfiles()
    private var selectionSnapshots: [CaptureMode: CameraSettings] = [:]
    var selectedPresetID: CameraPreset.ID? { selections[captureMode] }
    var unselectedSettings: CameraSettings { manualProfiles[captureMode] }
    var modePresets: [CameraPreset] { presets.filter { $0.captureMode == captureMode } }

    func activate(_ mode: CaptureMode) { captureMode = mode }
    private(set) var persistenceErrorDescription: String?

    private let repository: any CameraPresetRepository
    private var hasLoadedPresets = false
    private var hasLocalChanges = false
    private var persistenceTask: Task<Void, Never>?

    init(
        presets: [CameraPreset] = [],
        selectedPresetID: CameraPreset.ID? = nil,
        unselectedSettings: CameraSettings = .standard,
        repository: any CameraPresetRepository = JSONCameraPresetRepository()
    ) {
        self.presets = presets
        self.repository = repository
        selections[.photo] = selectedPresetID
        manualProfiles[.photo] = unselectedSettings
    }

    func load() async {
        guard !hasLoadedPresets else { return }
        hasLoadedPresets = true

        do {
            let savedPresets = try await repository.presets()
            guard !hasLocalChanges else { return }
            presets = savedPresets
            persistenceErrorDescription = nil
        } catch {
            persistenceErrorDescription = error.localizedDescription
        }
    }

    func save(_ preset: CameraPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        persistPresets()
    }

    func delete(id: CameraPreset.ID) {
        presets.removeAll { $0.id == id }
        for mode in [CaptureMode.photo, .video] where selections[mode] == id {
            selections[mode] = nil
            selectionSnapshots[mode] = nil
        }
        persistPresets()
    }

    func select(id: CameraPreset.ID, currentSettings: CameraSettings? = nil) {
        guard let preset = modePresets.first(where: { $0.id == id }) else { return }
        selections[captureMode] = id
        if let currentSettings {
            selectionSnapshots[captureMode] = preset.settings.applying(to: currentSettings)
        }
    }

    func clearSelection() {
        selections[captureMode] = nil
        selectionSnapshots[captureMode] = nil
    }

    func updateUnselectedSettings(_ settings: CameraSettings) {
        let mode = settings.captureMode
        if selections[mode] != nil {
            if let snapshot = selectionSnapshots[mode], snapshot != settings {
                selections[mode] = nil
                selectionSnapshots[mode] = nil
            } else { return }
        }
        manualProfiles[mode] = settings
    }

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var filtered = modePresets
        guard (0...filtered.count).contains(destination),
              offsets.allSatisfy({ filtered.indices.contains($0) }) else { return }
        let moving = offsets.sorted().map { filtered[$0] }
        for index in offsets.sorted(by: >) { filtered.remove(at: index) }
        let insertionIndex = destination - offsets.filter { $0 < destination }.count
        filtered.insert(contentsOf: moving, at: insertionIndex)
        var next = 0
        for index in presets.indices where presets[index].captureMode == captureMode {
            presets[index] = filtered[next]
            next += 1
        }
        persistPresets()
    }

    func waitForPendingPersistence() async {
        await persistenceTask?.value
    }

    private func persistPresets() {
        hasLocalChanges = true
        let snapshot = presets
        let precedingTask = persistenceTask

        persistenceTask = Task { [weak self, repository] in
            await precedingTask?.value
            do {
                try await repository.replaceAll(with: snapshot)
                self?.persistenceErrorDescription = nil
            } catch {
                self?.persistenceErrorDescription = error.localizedDescription
            }
        }
    }
}
