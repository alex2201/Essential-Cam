//
//  CameraPresetCarouselView.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import SwiftUI

struct CameraPresetCarouselView: View {
    @Environment(\.cameraIconRotationDegrees) private var rotationDegrees
    let store: CameraPresetStore
    let controls: CameraControlsController

    private var displayedPresetID: Binding<CameraPreset.ID?> {
        Binding(get: { store.selectedPresetID }, set: { id in
            guard !controls.isApplyingConfiguration else { return }
            if let id, let preset = store.modePresets.first(where: { $0.id == id }) {
                store.select(id: id, currentSettings: controls.settings)
                controls.applyPreset(preset.settings)
            } else {
                let settings = store.unselectedSettings
                store.clearSelection()
                controls.applyUnselectedSettings(settings)
            }
        })
    }

    var body: some View {
        HStack(spacing: 4) {
            carouselArrow(systemName: "chevron.left", offset: -1)

            if store.modePresets.isEmpty {
                Text("No presets available")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(abs(rotationDegrees) == 90 ? 3 : 1)
                    .minimumScaleFactor(0.25)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cameraControlContentRotation()
            } else {
                TabView(selection: displayedPresetID) {
                    presetLabel("No preset", accessibilityValue: "No preset")
                        .tag(CameraPreset.ID?.none)

                    ForEach(store.modePresets) { preset in
                        presetLabel(preset.name, accessibilityValue: preset.name)
                            .tag(Optional(preset.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

            }

            carouselArrow(systemName: "chevron.right", offset: 1)
        }
        .frame(width: 210, height: 44)
        .shadow(color: .black.opacity(0.65), radius: 2, y: 1)
    }

    private var displayedPageIndex: Int {
        guard let displayedPresetID = store.selectedPresetID,
              let presetIndex = store.modePresets.firstIndex(where: { $0.id == displayedPresetID })
        else {
            return 0
        }
        return presetIndex + 1
    }

    @ViewBuilder
    private func carouselArrow(systemName: String, offset: Int) -> some View {
        let destination = displayedPageIndex + offset
        Button {
            guard destination >= 0, destination <= store.modePresets.count else { return }
            displayedPresetID.wrappedValue = destination == 0 ? nil : store.modePresets[destination - 1].id
        } label: {
            Image(systemName: systemName)
                .cameraIconRotation()
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.modePresets.isEmpty || destination < 0 || destination > store.modePresets.count)
        .opacity(store.modePresets.isEmpty || destination < 0 || destination > store.modePresets.count ? 0.3 : 0.9)
        .accessibilityLabel(offset < 0 ? "Previous preset" : "Next preset")
    }

    private func presetLabel(_ text: String, accessibilityValue: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(abs(rotationDegrees) == 90 ? 3 : 1)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.25)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cameraControlContentRotation()
            .accessibilityLabel("Camera preset")
            .accessibilityValue(accessibilityValue)
    }
}
