//
//  JSONCameraPresetRepository.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Foundation

actor JSONCameraPresetRepository: CameraPresetRepository {
    private struct PresetFile: Codable {
        let version: Int
        var presets: [CameraPreset]
    }

    private static let currentVersion = 2

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        decoder = JSONDecoder()
    }

    func presets() throws -> [CameraPreset] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let file = try decoder.decode(PresetFile.self, from: data)
        guard (1...Self.currentVersion).contains(file.version) else { throw CocoaError(.coderReadCorrupt) }
        return file.presets
    }

    func save(_ preset: CameraPreset) throws {
        var savedPresets = try presets()

        if let index = savedPresets.firstIndex(where: { $0.id == preset.id }) {
            savedPresets[index] = preset
        } else {
            savedPresets.append(preset)
        }

        try persist(savedPresets)
    }

    func delete(id: UUID) throws {
        let savedPresets = try presets()
        let remainingPresets = savedPresets.filter { $0.id != id }
        guard remainingPresets.count != savedPresets.count else { return }
        try persist(remainingPresets)
    }

    func replaceAll(with presets: [CameraPreset]) throws {
        _ = try self.presets() // Preserve unreadable or newer files instead of silently overwriting them.
        try persist(presets)
    }

    private func persist(_ presets: [CameraPreset]) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let file = PresetFile(
            version: Self.currentVersion,
            presets: presets
        )
        try encoder.encode(file).write(to: fileURL, options: .atomic)
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        return applicationSupportURL
            .appendingPathComponent("CameraPresets", isDirectory: true)
            .appendingPathComponent("presets.json")
    }
}
