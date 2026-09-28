import CoreGraphics
import Foundation
import ImageIO

actor PendingPhotoStore {
    private struct Metadata: Codable {
        let uniformTypeIdentifier: String
    }

    private let directoryURL: URL

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
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
        try FileManager.default.createDirectory(
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

    func load() -> Photo? {
        guard
            let data = try? Data(contentsOf: dataURL),
            let metadataData = try? Data(contentsOf: metadataURL),
            let metadata = try? PropertyListDecoder().decode(
                Metadata.self,
                from: metadataData
            )
        else {
            return nil
        }

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

    func discard() {
        try? FileManager.default.removeItem(at: dataURL)
        try? FileManager.default.removeItem(at: metadataURL)
    }

    private var dataURL: URL {
        directoryURL.appendingPathComponent("capture.data")
    }

    private var metadataURL: URL {
        directoryURL.appendingPathComponent("metadata.plist")
    }
}
