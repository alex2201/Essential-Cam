//
//  VideoCaptureTests.swift
//  Essential Cam
//
//  Created by Codex on 04/10/26.
//

import AVFoundation
import Foundation
import Testing
@testable import Essential_Cam

struct VideoCaptureTests {
    @Test func saveFailureRetainsClipAndRetryDoesNotRecordAgain() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PendingVideoStore(directoryURL: directory)
        let recording = TestVideoRecording()
        let saving = TestVideoSaving(shouldFail: true)
        let coordinator = VideoCaptureCoordinator(recording: recording, saving: saving, store: store)
        await #expect(throws: VideoCaptureError.saveFailed) {
            try await coordinator.record(didStart: {}, didFinish: {})
        }
        #expect(await coordinator.hasPendingVideo())
        let restored = VideoCaptureCoordinator(recording: recording, saving: saving, store: store)
        #expect(try await restored.restorePendingVideo())
        await saving.setShouldFail(false)
        try await restored.retrySave()
        #expect(await recording.count == 1)
        #expect(await saving.count == 2)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        #expect(await restored.hasPendingVideo() == false)
    }

    @Test func pendingClipBlocksAnotherRecordingAndCanBeDiscarded() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let recording = TestVideoRecording()
        let coordinator = VideoCaptureCoordinator(recording: recording, saving: TestVideoSaving(shouldFail: true), store: PendingVideoStore(directoryURL: directory))
        await #expect(throws: VideoCaptureError.saveFailed) {
            try await coordinator.record(didStart: {}, didFinish: {})
        }
        await #expect(throws: VideoCaptureError.operationInProgress) {
            try await coordinator.record(didStart: {}, didFinish: {})
        }
        #expect(await recording.count == 1)
        try await coordinator.discard()
        #expect(await coordinator.hasPendingVideo() == false)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func failedRecordingDoesNotImportPartialFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let saving = TestVideoSaving()
        let coordinator = VideoCaptureCoordinator(recording: TestVideoRecording(shouldFail: true), saving: saving, store: PendingVideoStore(directoryURL: directory))
        await #expect(throws: VideoCaptureError.recordingFailed) {
            try await coordinator.record(didStart: {}, didFinish: {})
        }
        #expect(await saving.count == 0)
        #expect(await coordinator.hasPendingVideo() == false)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func savedTombstonePreventsReimportAfterRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PendingVideoStore(directoryURL: directory)
        let url = try await store.prepareRecording()
        try Data([1]).write(to: url)
        try await store.markReady()
        try await store.markSaved()
        #expect(try await PendingVideoStore(directoryURL: directory).load() == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func successfulImportDoesNotBecomeRetryWhenCleanupFails() async throws {
        let saving = TestVideoSaving()
        let store = TestVideoStore(failCleanup: true)
        let coordinator = VideoCaptureCoordinator(recording: TestVideoRecording(), saving: saving, store: store)
        try await coordinator.record(didStart: {}, didFinish: {})
        #expect(await saving.count == 1)
        #expect(await coordinator.hasPendingVideo() == false)
        #expect(await store.markedSaved)
        await #expect(throws: VideoCaptureError.recordingFailed) { try await coordinator.retrySave() }
        #expect(await saving.count == 1)
    }

    @Test func canceledStartDoesNotRecordOrSave() async throws {
        let recording = TestVideoRecording()
        let saving = TestVideoSaving()
        let store = TestVideoStore(holdPreparation: true)
        let coordinator = VideoCaptureCoordinator(recording: recording, saving: saving, store: store)
        let task = Task { try await coordinator.record(didStart: {}, didFinish: {}) }
        await store.waitUntilPreparing()
        task.cancel()
        await store.finishPreparing()
        do {
            try await task.value
            Issue.record("A canceled start must not record")
        } catch is CancellationError {}
        #expect(await recording.count == 0)
        #expect(await saving.count == 0)
        #expect(await store.discarded)
    }

    @Test func missingPendingFileIsReportedInsteadOfBeingOverwritten() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PendingVideoStore(directoryURL: directory)
        _ = try await store.prepareRecording()
        await #expect(throws: VideoCaptureError.pendingStorageFailed) { _ = try await store.load() }
        await #expect(throws: VideoCaptureError.pendingStorageFailed) { _ = try await store.prepareRecording() }
        try await store.discard()
    }

    @Test func delegateDistinguishesPlayableCompletionFromRecordingFailure() {
        #expect(VideoRecordingResult.isSuccessful(error: nil))
        #expect(VideoRecordingResult.isSuccessful(error: NSError(domain: AVFoundationErrorDomain, code: -1, userInfo: [AVErrorRecordingSuccessfullyFinishedKey: true])))
        #expect(!VideoRecordingResult.isSuccessful(error: NSError(domain: AVFoundationErrorDomain, code: -1, userInfo: [AVErrorRecordingSuccessfullyFinishedKey: false])))
        #expect(!VideoRecordingResult.isSuccessful(error: NSError(domain: AVFoundationErrorDomain, code: -1)))
    }
}

private actor TestVideoRecording: VideoRecording {
    private(set) var count = 0
    private let shouldFail: Bool
    init(shouldFail: Bool = false) { self.shouldFail = shouldFail }
    func recordVideo(to url: URL, didStart: @escaping @Sendable () -> Void) async throws {
        count += 1
        didStart()
        // The real store uses an isolated temporary directory. The in-memory
        // store does not need actual movie bytes for cleanup failure tests.
        if FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path) {
            try Data([1, 2, 3]).write(to: url)
        }
        if shouldFail { throw VideoCaptureError.recordingFailed }
    }
    func stopVideoRecording() {}
}

private actor TestVideoSaving: VideoSaving {
    private var shouldFail: Bool
    private(set) var count = 0
    init(shouldFail: Bool = false) { self.shouldFail = shouldFail }
    func setShouldFail(_ value: Bool) { shouldFail = value }
    func saveVideo(at url: URL) throws {
        count += 1
        if shouldFail { throw VideoCaptureError.saveFailed }
    }
}

private actor TestVideoStore: PendingVideoStoring {
    private let failCleanup: Bool
    private let holdPreparation: Bool
    private var preparation: CheckedContinuation<Void, Never>?
    private var preparingWaiter: CheckedContinuation<Void, Never>?
    private var preparing = false
    private(set) var markedSaved = false
    private(set) var discarded = false
    init(failCleanup: Bool = false, holdPreparation: Bool = false) {
        self.failCleanup = failCleanup
        self.holdPreparation = holdPreparation
    }
    func prepareRecording() async -> URL {
        preparing = true
        if holdPreparation {
            await withCheckedContinuation {
                preparation = $0
                preparingWaiter?.resume()
                preparingWaiter = nil
            }
        }
        return URL(fileURLWithPath: "/nonexistent/test-video.mov")
    }
    func waitUntilPreparing() async {
        if preparing { return }
        await withCheckedContinuation { preparingWaiter = $0 }
    }
    func finishPreparing() { preparation?.resume(); preparation = nil }
    func markReady() {}
    func markSaved() { markedSaved = true }
    func load() -> URL? { nil }
    func discard() throws {
        if failCleanup { throw VideoCaptureError.pendingStorageFailed }
        discarded = true
    }
}
