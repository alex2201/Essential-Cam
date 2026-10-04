@MainActor
protocol CameraPresetsLoading: AnyObject {
    func load() async
}

@MainActor
struct LoadApplicationUseCase {
    let loadQuickSettings: LoadQuickSettingsUseCase
    let presetStore: any CameraPresetsLoading

    func execute() async {
        loadQuickSettings.execute()
        await presetStore.load()
    }
}
