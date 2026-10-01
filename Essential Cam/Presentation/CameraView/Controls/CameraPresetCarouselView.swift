import SwiftUI

struct CameraPresetCarouselView: View {
    let store: CameraPresetStore
    let controls: CameraControlsController

    @State private var displayedPresetID: CameraPreset.ID?

    var body: some View {
        HStack(spacing: 4) {
            carouselArrow(systemName: "chevron.left", offset: -1)

            if store.presets.isEmpty {
                Text("No presets available")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: $displayedPresetID) {
                    presetLabel("No preset", accessibilityValue: "No preset")
                        .tag(CameraPreset.ID?.none)

                    ForEach(store.presets) { preset in
                        presetLabel(preset.name, accessibilityValue: preset.name)
                            .tag(Optional(preset.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: displayedPresetID) { _, presetID in
                    guard let presetID else {
                        let unselectedSettings = store.unselectedSettings
                        store.clearSelection()
                        controls.applyUnselectedSettings(unselectedSettings)
                        return
                    }
                    guard let preset = store.presets.first(where: { $0.id == presetID }) else {
                        return
                    }
                    store.select(id: presetID)
                    controls.applyPreset(preset.settings)
                }
            }

            carouselArrow(systemName: "chevron.right", offset: 1)
        }
        .frame(width: 210, height: 44)
        .shadow(color: .black.opacity(0.65), radius: 2, y: 1)
        .task(id: store.presets) {
            synchronizeSelection()
        }
    }

    private func synchronizeSelection() {
        guard let selectedPresetID = store.selectedPresetID,
              store.presets.contains(where: { $0.id == selectedPresetID })
        else {
            displayedPresetID = nil
            store.clearSelection()
            return
        }
        displayedPresetID = selectedPresetID
    }

    private var displayedPageIndex: Int {
        guard let displayedPresetID,
              let presetIndex = store.presets.firstIndex(where: { $0.id == displayedPresetID })
        else {
            return 0
        }
        return presetIndex + 1
    }

    @ViewBuilder
    private func carouselArrow(systemName: String, offset: Int) -> some View {
        let destination = displayedPageIndex + offset
        Button {
            guard destination >= 0, destination <= store.presets.count else { return }
            displayedPresetID = destination == 0 ? nil : store.presets[destination - 1].id
        } label: {
            Image(systemName: systemName)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.presets.isEmpty || destination < 0 || destination > store.presets.count)
        .opacity(store.presets.isEmpty || destination < 0 || destination > store.presets.count ? 0.3 : 0.9)
        .accessibilityLabel(offset < 0 ? "Previous preset" : "Next preset")
    }

    private func presetLabel(_ text: String, accessibilityValue: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Camera preset")
            .accessibilityValue(accessibilityValue)
    }
}
