//
//  PendingVideoStore.swift
//  Essential Cam
//
//  Created by Alexander López on 04/10/26.
//

import AVFoundation
import Foundation

actor PendingVideoStore: PendingVideoStoring {
    private enum Status: String, Codable { case recording, ready, saved }
    private let directoryURL: URL
    private let fileManager: FileManager

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("PendingVideo", isDirectory: true)
    }

    func prepareRecording() throws -> URL {
        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            throw VideoCaptureError.pendingStorageFailed
        }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try write(.recording)
        return videoURL
    }

    func markReady() throws { try write(.ready) }
    func markSaved() throws { try write(.saved) }

    func load() async throws -> URL? {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return nil }
        let metadata = try PropertyListDecoder().decode([String: Status].self, from: Data(contentsOf: statusURL))
        guard let status = metadata["status"] else { throw VideoCaptureError.pendingStorageFailed }
        if status == .saved {
            // This tombstone prevents a failed cleanup from importing the same clip again.
            try discard()
            return nil
        }
        guard fileManager.fileExists(atPath: videoURL.path) else {
            throw VideoCaptureError.pendingStorageFailed
        }
        if status == .recording {
            // A process termination may leave an unfinished movie. Recover only
            // files that AVFoundation can read; never present an invalid clip as saved.
            let asset = AVURLAsset(url: videoURL)
            guard try await asset.load(.isPlayable), try await asset.load(.duration).seconds > 0 else {
                throw VideoCaptureError.pendingStorageFailed
            }
            try markReady()
        }
        return videoURL
    }

    func discard() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
    }

    private func write(_ status: Status) throws {
        // Encode a keyed container: property lists do not support a top-level string.
        try PropertyListEncoder().encode(["status": status]).write(to: statusURL, options: .atomic)
    }

    private var videoURL: URL { directoryURL.appendingPathComponent("recording.mov") }
    private var statusURL: URL { directoryURL.appendingPathComponent("status.plist") }
}
