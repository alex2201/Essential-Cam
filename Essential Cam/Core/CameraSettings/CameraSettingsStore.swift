import Foundation

struct CameraSettingsStore {
    private let defaults: UserDefaults
    private let key = "camera.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CameraSettings {
        guard
            let data = defaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(CameraSettings.self, from: data)
        else {
            return .standard
        }
        return settings
    }

    func save(_ settings: CameraSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
