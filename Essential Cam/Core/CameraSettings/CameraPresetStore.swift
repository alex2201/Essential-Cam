import Foundation
import Observation

@MainActor
@Observable
final class CameraPresetStore {
    private(set) var presets: [CameraPreset]
    private(set) var selectedPresetID: CameraPreset.ID?
    private(set) var unselectedSettings: CameraSettings

    init(
        presets: [CameraPreset] = [],
        selectedPresetID: CameraPreset.ID? = nil,
        unselectedSettings: CameraSettings = .standard
    ) {
        self.presets = presets
        self.selectedPresetID = selectedPresetID
        self.unselectedSettings = unselectedSettings
    }

    func save(_ preset: CameraPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
    }

    func delete(id: CameraPreset.ID) {
        presets.removeAll { $0.id == id }
        if selectedPresetID == id {
            selectedPresetID = nil
        }
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
    }
}
