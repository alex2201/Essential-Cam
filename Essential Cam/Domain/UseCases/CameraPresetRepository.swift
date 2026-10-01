import Foundation

protocol CameraPresetRepository: Sendable {
    func presets() async throws -> [CameraPreset]
    func save(_ preset: CameraPreset) async throws
    func delete(id: UUID) async throws
    func replaceAll(with presets: [CameraPreset]) async throws
}
