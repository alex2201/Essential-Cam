import CoreGraphics
import Foundation
import ImageIO

protocol PendingPhotoStoring: Sendable {
    func save(_ photo: Photo) async throws
    func load() async throws -> Photo?
    func discard() async throws
}

actor PendingPhotoStore: PendingPhotoStoring {
    private struct Metadata: Codable {
        let uniformTypeIdentifier: String
    }

    private let directoryURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
            return
        }
        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        self.directoryURL = baseURL.appendingPathComponent(
            "PendingCapture",
            isDirectory: true
        )
    }

    func save(_ photo: Photo) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try photo.data.write(to: dataURL, options: .atomic)
        let metadata = Metadata(
            uniformTypeIdentifier: photo.uniformTypeIdentifier
        )
        try PropertyListEncoder().encode(metadata).write(
            to: metadataURL,
            options: .atomic
        )
    }

    func load() throws -> Photo? {
        let hasData = fileManager.fileExists(atPath: dataURL.path)
        let hasMetadata = fileManager.fileExists(atPath: metadataURL.path)
        guard hasData || hasMetadata else {
            return nil
        }

        let data = try Data(contentsOf: dataURL)
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try PropertyListDecoder().decode(
            Metadata.self,
            from: metadataData
        )

        let preview = CGImageSourceCreateWithData(data as CFData, nil)
            .flatMap { CGImageSourceCreateThumbnailAtIndex(
                $0,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 400,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ] as CFDictionary
            ) }

        return Photo(
            data: data,
            previewImage: preview,
            uniformTypeIdentifier: metadata.uniformTypeIdentifier
        )
    }

    func discard() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
    }

    private var dataURL: URL {
        directoryURL.appendingPathComponent("capture.data")
    }

    private var metadataURL: URL {
        directoryURL.appendingPathComponent("metadata.plist")
    }
}
