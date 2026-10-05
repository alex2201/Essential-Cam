//
//  QuickSettingsCustomizationView.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import SwiftUI

struct QuickSettingsCustomizationView: View {
    @Environment(QuickSettingsStore.self) private var store

    private let repository: (any QuickSettingsRepository)?

    init(repository: (any QuickSettingsRepository)? = nil) {
        self.repository = repository
    }

    private var customization: CustomizeQuickSettingsUseCase {
        CustomizeQuickSettingsUseCase(store: store, repository: repository ?? UserDefaultsQuickSettingsRepository(mode: store.captureMode))
    }

    var body: some View {
        List {
            Section {
                if store.included.isEmpty {
                    Text("No quick settings included")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.included) { control in
                    HStack {
                        Text(control.title)
                        Spacer()
                        Button {
                            customization.execute(.remove(control))
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(control.title)")
                    }
                    .moveDisabled(false)
                    // A shortcut changes row behavior when it changes sections.
                    .id("included.\(control.id)")
                }
                .onMove { offsets, destination in
                    customization.execute(.move(offsets, destination: destination))
                }
            } header: {
                Text("Included")
            } footer: {
                Text("Drag the handles to reorder. Removing a shortcut keeps its camera setting unchanged.")
            }

            Section("Available") {
                if customization.available.isEmpty {
                    Text("All controls are included")
                        .foregroundStyle(.secondary)
                }
                ForEach(customization.available) { control in
                    HStack {
                        Text(control.title)
                        Spacer()
                        Button {
                            customization.execute(.add(control))
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Add \(control.title)")
                    }
                    .moveDisabled(true)
                    .id("available.\(control.id)")
                }
            }

        }
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { customization.execute(.reset) }
            }
        }
        .navigationTitle("\(store.captureMode.accessibilityName) Quick Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
