import Foundation

@MainActor
struct UserDefaultsQuickSettingsRepository: QuickSettingsRepository {
    private let defaults: UserDefaults
    private let key = "camera.quickSettings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadIdentifiers() -> [String]? {
        defaults.stringArray(forKey: key)
    }

    func saveIdentifiers(_ identifiers: [String]) {
        defaults.set(identifiers, forKey: key)
    }
}
