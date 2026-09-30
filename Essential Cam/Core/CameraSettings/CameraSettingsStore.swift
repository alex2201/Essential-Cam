import Foundation

struct CameraSettingsStore {
    private let defaults: UserDefaults
    private let key = "camera.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CameraSettings {
        guard let data = defaults.data(forKey: key) else {
            return .standard
        }
        do {
            return try JSONDecoder().decode(CameraSettings.self, from: data)
        } catch {
            // TODO: Track this error with the integrated logging service.
            return .standard
        }
    }

    func save(_ settings: CameraSettings) {
        do {
            defaults.set(try JSONEncoder().encode(settings), forKey: key)
        } catch {
            // TODO: Track this error with the integrated logging service.
        }
    }
}
