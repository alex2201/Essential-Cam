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

    @Test func failedRecordingRetainsUnplayableFileForExplicitDiscard() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let saving = TestVideoSaving()
        let coordinator = VideoCaptureCoordinator(recording: TestVideoRecording(shouldFail: true), saving: saving, store: PendingVideoStore(directoryURL: directory))
        await #expect(throws: VideoCaptureError.pendingStorageFailed) {
            try await coordinator.record(didStart: {}, didFinish: {})
        }
        #expect(await saving.count == 0)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("recording.mov").path))
        await #expect(throws: VideoCaptureError.pendingStorageFailed) { try await coordinator.retrySave() }
        let restored = VideoCaptureCoordinator(recording: TestVideoRecording(), saving: saving, store: PendingVideoStore(directoryURL: directory))
        await #expect(throws: VideoCaptureError.pendingStorageFailed) { _ = try await restored.restorePendingVideo() }
        try await restored.discard()
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func failedRecordingWithRecoverableFileCanBeRetriedWithoutRecordingAgain() async throws {
        let recording = TestVideoRecording(shouldFail: true)
        let saving = TestVideoSaving()
        let store = TestVideoStore(recoverableFile: true)
        let coordinator = VideoCaptureCoordinator(recording: recording, saving: saving, store: store)
        await #expect(throws: VideoCaptureError.saveFailed) {
            try await coordinator.record(didStart: {}, didFinish: {})
        }
        #expect(await coordinator.hasPendingVideo())
        #expect(await saving.count == 0)
        #expect(await store.discarded == false)
        await #expect(throws: VideoCaptureError.operationInProgress) {
            try await coordinator.record(didStart: {}, didFinish: {})
        }
        try await coordinator.retrySave()
        #expect(await saving.count == 1)
        #expect(await recording.count == 1)
        #expect(await coordinator.hasPendingVideo() == false)
    }

    @Test func playableFileLeftInRecordingStateIsRecoveredAfterRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PendingVideoStore(directoryURL: directory)
        let url = try await store.prepareRecording()
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 32,
            AVVideoHeightKey: 32
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 32,
            kCVPixelBufferHeightKey as String: 32
        ])
        writer.add(input)
        try #require(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var pixelBuffer: CVPixelBuffer?
        try #require(CVPixelBufferCreate(kCFAllocatorDefault, 32, 32, kCVPixelFormatType_32BGRA, nil, &pixelBuffer) == kCVReturnSuccess)
        let buffer = try #require(pixelBuffer)
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 0, CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        for _ in 0..<100 where !input.isReadyForMoreMediaData {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(input.isReadyForMoreMediaData)
        try #require(adaptor.append(buffer, withPresentationTime: .zero))
        try #require(adaptor.append(buffer, withPresentationTime: CMTime(value: 1, timescale: 30)))
        input.markAsFinished()
        writer.finishWriting {}
        for _ in 0..<200 where writer.status == .writing {
            try await Task.sleep(for: .milliseconds(10))
        }
        if writer.status == .writing { writer.cancelWriting() }
        try #require(writer.status == .completed)
        let restored = PendingVideoStore(directoryURL: directory)
        #expect(try await restored.load() == url)
        // Validation also persists readiness so another relaunch can recover it.
        #expect(try await PendingVideoStore(directoryURL: directory).load() == url)
        try await restored.discard()
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
    private let recoverableFile: Bool
    private var preparation: CheckedContinuation<Void, Never>?
    private var preparingWaiter: CheckedContinuation<Void, Never>?
    private var preparing = false
    private(set) var markedSaved = false
    private(set) var discarded = false
    init(failCleanup: Bool = false, holdPreparation: Bool = false, recoverableFile: Bool = false) {
        self.failCleanup = failCleanup
        self.holdPreparation = holdPreparation
        self.recoverableFile = recoverableFile
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
    func load() -> URL? { recoverableFile ? URL(fileURLWithPath: "/nonexistent/test-video.mov") : nil }
    func discard() throws {
        if failCleanup { throw VideoCaptureError.pendingStorageFailed }
        discarded = true
    }
}
