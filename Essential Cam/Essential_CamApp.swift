import SwiftUI

@main
struct Essential_CamApp: App {
    @State private var quickSettingsStore = QuickSettingsStore()
    @State private var presetStore = CameraPresetStore()
    @State private var isApplicationLoaded = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isApplicationLoaded {
                    CameraView()
                } else {
                    ApplicationLoadingView()
                }
            }
            .environment(presetStore)
            .environment(quickSettingsStore)
            .task {
                guard !isApplicationLoaded else { return }
                let loadApplication = LoadApplicationUseCase(
                    loadQuickSettings: LoadQuickSettingsUseCase(
                        store: quickSettingsStore,
                        repository: UserDefaultsQuickSettingsRepository()
                    ),
                    presetStore: presetStore
                )
                await loadApplication.execute()
                isApplicationLoaded = true
            }
        }
    }
}
