//
//  Essential_CamApp.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import SwiftUI

@main
struct Essential_CamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var quickSettingsStore = QuickSettingsStore()
    @State private var presetStore = CameraPresetStore()
    @State private var isApplicationLoaded = false
    @State private var isPreparingApplication = false
    @State private var storageWarning: StartupStorageWarning?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isApplicationLoaded {
                    if hasCompletedOnboarding {
                        CameraView()
                    } else {
                        OnboardingView {
                            hasCompletedOnboarding = true
                        }
                    }
                } else {
                    ApplicationLoadingView()
                        .alert(item: $storageWarning) { warning in
                            Alert(
                                title: Text(warning.title),
                                message: Text(warning.message),
                                dismissButton: .default(Text("Continue")) {
                                    isApplicationLoaded = true
                                }
                            )
                        }
                }
            }
            .environment(presetStore)
            .environment(quickSettingsStore)
            .task {
                guard !isApplicationLoaded, !isPreparingApplication, storageWarning == nil else { return }
                isPreparingApplication = true
                defer { isPreparingApplication = false }
                let loadApplication = LoadApplicationUseCase(
                    loadQuickSettings: LoadQuickSettingsUseCase(
                        store: quickSettingsStore,
                        repository: UserDefaultsQuickSettingsRepository()
                    ),
                    presetStore: presetStore
                )
                await loadApplication.execute()
                quickSettingsStore.captureMode = .video
                LoadQuickSettingsUseCase(
                    store: quickSettingsStore,
                    repository: UserDefaultsQuickSettingsRepository(mode: .video)
                ).execute()
                quickSettingsStore.captureMode = .photo
                guard !Task.isCancelled else { return }
                let result = await CheckStorageUseCase(storage: DefaultStorageCapacity()).execute()
                guard !Task.isCancelled else { return }
                storageWarning = StartupStorageWarning(result: result)
                isApplicationLoaded = storageWarning == nil
            }
        }
    }
}
