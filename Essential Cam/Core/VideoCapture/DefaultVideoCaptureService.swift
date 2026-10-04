//
//  DefaultVideoCaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

import AVFoundation
import Foundation

/// All output mutation and delegate retention are confined to CameraSession's executor.
final class DefaultVideoCaptureService: VideoCaptureService {
    var output: AVCaptureOutput { videoOutput }
    private let videoOutput = AVCaptureMovieFileOutput()
    private var activeDelegate: VideoRecordingDelegate?

    func record(to url: URL, didStart: @escaping @Sendable () -> Void) async throws {
        guard !videoOutput.isRecording, activeDelegate == nil,
              let connection = videoOutput.connection(with: .video), connection.isActive else {
            throw VideoCaptureError.recordingFailed
        }
        if videoOutput.availableVideoCodecTypes.contains(.h264) {
            videoOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.h264], for: connection)
        }
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .standard
        }
        videoOutput.minFreeDiskSpaceLimit = 100 * 1_024 * 1_024
        defer { activeDelegate = nil }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = VideoRecordingDelegate(didStart: didStart, continuation: continuation)
            activeDelegate = delegate
            videoOutput.startRecording(to: url, recordingDelegate: delegate)
        }
    }

    func stopRecording() {
        if videoOutput.isRecording { videoOutput.stopRecording() }
    }
}

/// Immutable callbacks safely carry results from AVFoundation's delegate queue.
private final class VideoRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, Sendable {
    private let didStart: @Sendable () -> Void
    private let continuation: CheckedContinuation<Void, Error>

    init(didStart: @escaping @Sendable () -> Void, continuation: CheckedContinuation<Void, Error>) {
        self.didStart = didStart
        self.continuation = continuation
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        didStart()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error, !VideoRecordingResult.isSuccessful(error: error) {
            continuation.resume(throwing: VideoCaptureError.recordingFailed)
        } else {
            continuation.resume()
        }
    }
}

enum VideoRecordingResult {
    static func isSuccessful(error: Error?) -> Bool {
        guard let error else { return true }
        return (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
    }
}
