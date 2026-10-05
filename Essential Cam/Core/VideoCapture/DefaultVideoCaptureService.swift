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

    var availableCodecs: [VideoCodec] {
        VideoCodec.allCases.filter { videoOutput.availableVideoCodecTypes.contains($0.avFoundationValue) }
    }

    func configure(_ settings: VideoSettings) throws {
        guard let connection = videoOutput.connection(with: .video),
              availableCodecs.contains(settings.codec) else {
            throw VideoCaptureError.unsupportedConfiguration
        }
        videoOutput.setOutputSettings([AVVideoCodecKey: settings.codec.avFoundationValue], for: connection)
        connection.preferredVideoStabilizationMode = settings.stabilization.avFoundationValue
    }

    func record(to url: URL, didStart: @escaping @Sendable () -> Void) async throws {
        guard !videoOutput.isRecording, activeDelegate == nil,
              let connection = videoOutput.connection(with: .video), connection.isActive else {
            throw VideoCaptureError.recordingFailed
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

extension VideoCodec {
    var avFoundationValue: AVVideoCodecType { self == .h264 ? .h264 : .hevc }
}

extension VideoStabilization {
    var avFoundationValue: AVCaptureVideoStabilizationMode {
        switch self {
        case .off: .off
        case .standard: .standard
        case .cinematic: .cinematic
        case .cinematicExtended: .cinematicExtended
        }
    }
}
