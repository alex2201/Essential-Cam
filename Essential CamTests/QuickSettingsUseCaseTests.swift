import Foundation
import Testing
@testable import Essential_Cam

@MainActor
struct QuickSettingsUseCaseTests {
    @Test func loadingPreservesEmptySelectionAndSanitizesIdentifiers() {
        let repository = MemoryQuickSettingsRepository()
        let store = QuickSettingsStore()
        let load = LoadQuickSettingsUseCase(store: store, repository: repository)
        load.execute()
        #expect(store.included == [.exposure, .focus, .whiteBalance])
        repository.identifiers = []
        load.execute()
        #expect(store.included.isEmpty)
        repository.identifiers = ["focus", "unknown", "focus", "exposure"]
        load.execute()
        #expect(store.included == [.focus, .exposure])
    }

    @Test func modificationsPersistImmediatelyAndRestoreInOrder() throws {
        let name = "QuickSettingsTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let repository = UserDefaultsQuickSettingsRepository(defaults: defaults)
        let store = QuickSettingsStore()
        LoadQuickSettingsUseCase(store: store, repository: repository).execute()
        let customize = CustomizeQuickSettingsUseCase(store: store, repository: repository)
        customize.execute(.add(.photoTimer))
        #expect(repository.loadIdentifiers() == ["exposure", "focus", "whiteBalance", "photoTimer"])
        customize.execute(.add(.photoTimer))
        #expect(store.included.count == 4)
        customize.execute(.move(IndexSet([0, 2]), destination: 4))
        #expect(repository.loadIdentifiers() == ["focus", "photoTimer", "exposure", "whiteBalance"])
        customize.execute(.remove(.focus))
        #expect(repository.loadIdentifiers() == ["photoTimer", "exposure", "whiteBalance"])
        #expect(customize.available.contains(.focus))
        let restored = QuickSettingsStore()
        LoadQuickSettingsUseCase(store: restored, repository: repository).execute()
        #expect(restored.included == store.included)
        customize.execute(.reset)
        #expect(repository.loadIdentifiers() == ["exposure", "focus", "whiteBalance"])
        customize.execute(.move(IndexSet([99]), destination: 0))
        #expect(store.included == QuickSettingControl.initialControls)
    }

    @Test func applicationLoadingAwaitsPresets() async {
        let store = QuickSettingsStore()
        let repository = MemoryQuickSettingsRepository()
        repository.identifiers = ["focus"]
        let presets = TestPresetsLoader(store: store)
        await LoadApplicationUseCase(
            loadQuickSettings: LoadQuickSettingsUseCase(store: store, repository: repository),
            presetStore: presets
        ).execute()
        #expect(presets.completed)
        #expect(store.included == [.focus])
    }
}

@MainActor
private final class MemoryQuickSettingsRepository: QuickSettingsRepository {
    var identifiers: [String]?
    func loadIdentifiers() -> [String]? { identifiers }
    func saveIdentifiers(_ identifiers: [String]) { self.identifiers = identifiers }
}

@MainActor
private final class TestPresetsLoader: CameraPresetsLoading {
    let store: QuickSettingsStore
    var completed = false
    init(store: QuickSettingsStore) { self.store = store }
    func load() async {
        #expect(store.included == [.focus])
        await Task.yield()
        completed = true
    }
}
