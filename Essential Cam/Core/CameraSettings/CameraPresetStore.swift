import Foundation
import Observation

@MainActor
@Observable
final class CameraPresetStore: CameraPresetsLoading {
    private(set) var presets: [CameraPreset]
    private(set) var selectedPresetID: CameraPreset.ID?
    private(set) var unselectedSettings: CameraSettings
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
        self.selectedPresetID = selectedPresetID
        self.unselectedSettings = unselectedSettings
        self.repository = repository
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
        if selectedPresetID == id {
            selectedPresetID = nil
        }
        persistPresets()
    }

    func select(id: CameraPreset.ID) {
        guard presets.contains(where: { $0.id == id }) else { return }
        selectedPresetID = id
    }

    func clearSelection() {
        selectedPresetID = nil
    }

    func updateUnselectedSettings(_ settings: CameraSettings) {
        guard selectedPresetID == nil else { return }
        unselectedSettings = settings
    }

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let movingPresets = offsets.sorted().map { presets[$0] }

        for index in offsets.sorted(by: >) {
            presets.remove(at: index)
        }

        let removedBeforeDestination = offsets.filter { $0 < destination }.count
        let insertionIndex = destination - removedBeforeDestination
        presets.insert(contentsOf: movingPresets, at: insertionIndex)
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
