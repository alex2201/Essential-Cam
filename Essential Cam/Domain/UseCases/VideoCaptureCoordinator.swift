//
//  VideoCaptureCoordinator.swift
//  Essential Cam
//
//  Created by Codex on 04/10/26.
//

import Foundation

protocol VideoRecording: Sendable {
    func recordVideo(to url: URL, didStart: @escaping @Sendable () -> Void) async throws
    func stopVideoRecording() async
}

protocol VideoSaving: Sendable {
    func saveVideo(at url: URL) async throws
}

protocol PendingVideoStoring: Sendable {
    func prepareRecording() async throws -> URL
    func markReady() async throws
    func load() async throws -> URL?
    func markSaved() async throws
    func discard() async throws
}

enum VideoCaptureError: Error, Equatable {
    case recordingFailed
    case unsupportedConfiguration
    case operationInProgress
    case pendingStorageFailed
    case saveFailed
}

protocol VideoCaptureCoordinating: Sendable {
    func record(didStart: @escaping @Sendable () -> Void, didFinish: @escaping @Sendable () -> Void) async throws
    func restorePendingVideo() async throws -> Bool
    func retrySave() async throws
    func discard() async throws
    func hasPendingVideo() async -> Bool
}

/// Retained for the recording lifecycle and for recovery of a pending file.
actor VideoCaptureCoordinator: VideoCaptureCoordinating {
    private let recording: any VideoRecording
    private let saving: any VideoSaving
    private let store: any PendingVideoStoring
    private var pendingURL: URL?
    private var isRecording = false

    init(recording: any VideoRecording, saving: any VideoSaving, store: any PendingVideoStoring) {
        self.recording = recording
        self.saving = saving
        self.store = store
    }

    func record(didStart: @escaping @Sendable () -> Void, didFinish: @escaping @Sendable () -> Void) async throws {
        guard !isRecording, pendingURL == nil else { throw VideoCaptureError.operationInProgress }
        isRecording = true
        defer { isRecording = false }
        let url: URL
        do {
            url = try await store.prepareRecording()
        } catch {
            throw VideoCaptureError.pendingStorageFailed
        }
        do {
            try Task.checkCancellation()
        } catch {
            // No recording has been requested yet, so there is no clip to recover.
            do { try await store.discard() } catch { throw VideoCaptureError.pendingStorageFailed }
            throw error
        }
        do {
            try await recording.recordVideo(to: url, didStart: didStart)
        } catch {
            // Preserve files left by a failed attempt. Once recording returns,
            // the store validates the file before allowing a retry.
            didFinish()
            do { pendingURL = try await store.load() } catch {
                throw VideoCaptureError.pendingStorageFailed
            }
            throw pendingURL == nil ? VideoCaptureError.recordingFailed : .saveFailed
        }
        didFinish()
        pendingURL = url
        do { try await store.markReady() } catch { throw VideoCaptureError.pendingStorageFailed }
        try await savePendingVideo()
    }

    func restorePendingVideo() async throws -> Bool {
        guard !isRecording else { throw VideoCaptureError.operationInProgress }
        if pendingURL == nil { pendingURL = try await store.load() }
        return pendingURL != nil
    }

    func hasPendingVideo() -> Bool { pendingURL != nil }

    func retrySave() async throws {
        guard !isRecording else { throw VideoCaptureError.operationInProgress }
        isRecording = true
        defer { isRecording = false }
        if pendingURL == nil { pendingURL = try await store.load() }
        guard pendingURL != nil else { throw VideoCaptureError.recordingFailed }
        try await store.markReady()
        try await savePendingVideo()
    }

    func discard() async throws {
        guard !isRecording else { throw VideoCaptureError.operationInProgress }
        try await store.discard()
        pendingURL = nil
    }

    private func savePendingVideo() async throws {
        guard let url = pendingURL else { throw VideoCaptureError.recordingFailed }
        do { try await saving.saveVideo(at: url) } catch { throw VideoCaptureError.saveFailed }
        // A successful Photo Library import must not be repeated because cleanup failed.
        pendingURL = nil
        try? await store.markSaved()
        try? await store.discard()
    }
}
