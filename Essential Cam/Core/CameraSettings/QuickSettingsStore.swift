import Observation

@MainActor
@Observable
final class QuickSettingsStore: QuickSettingsStoring {
    var included: [QuickSettingControl] = []
}
