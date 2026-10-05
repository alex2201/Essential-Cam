//
//  VideoMicrophoneRouter.swift
//  Essential Cam
//
//  Created by Codex.
//

import AVFoundation
import OSLog

/// Called synchronously only on CameraSession's serial executor.
enum VideoMicrophoneRouter {
    private static let logger = Logger(subsystem: "com.alexanderlopez.Essential-Cam", category: "video.audio")

    static func availableMicrophones() -> [VideoMicrophone] {
        let audio = AVAudioSession.sharedInstance()
        if audio.category == .record || audio.category == .playAndRecord || audio.category == .multiRoute {
            return (audio.availableInputs ?? []).map {
                VideoMicrophone(id: $0.uid, name: $0.portName, isBuiltIn: $0.portType == .builtInMic)
            }
        }
        let category = audio.category
        let mode = audio.mode
        let options = audio.categoryOptions
        // availableInputs depends on category/mode. Discovery never activates audio or requests permission.
        defer {
            if audio.category != category || audio.mode != mode || audio.categoryOptions != options {
                try? audio.setCategory(category, mode: mode, options: options)
            }
        }
        do {
            try audio.setCategory(.playAndRecord, mode: .videoRecording, options: bluetoothOptions)
            return (audio.availableInputs ?? []).map {
                VideoMicrophone(id: $0.uid, name: $0.portName, isBuiltIn: $0.portType == .builtInMic)
            }
        } catch {
            logger.error("Couldn't discover audio inputs: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Returns whether the app activated audio and must release it when recording ends.
    static func configure(_ selection: VideoMicrophoneSelection, cameraPosition: AVCaptureDevice.Position,
                          captureSession: AVCaptureSession) throws -> Bool {
        let audio = AVAudioSession.sharedInstance()
        guard selection != .automatic else {
            captureSession.automaticallyConfiguresApplicationAudioSession = true
            return false
        }
        captureSession.automaticallyConfiguresApplicationAudioSession = false
        do {
            try audio.setCategory(.playAndRecord, mode: .videoRecording, options: bluetoothOptions)
            try audio.setActive(true)
            let inputs = audio.availableInputs ?? []
            let descriptions = inputs.map {
                VideoMicrophone(id: $0.uid, name: $0.portName, isBuiltIn: $0.portType == .builtInMic)
            }
            let selectedID = selection.resolvedInput(in: descriptions)?.id
            let selected = inputs.first { $0.uid == selectedID }
            if let selected {
                try audio.setPreferredInput(selected)
                if selected.portType == .builtInMic, let sources = selected.dataSources, !sources.isEmpty {
                    let orientation: AVAudioSession.Orientation = cameraPosition == .front ? .front : .back
                    let source = sources.first { $0.orientation == orientation }
                    try selected.setPreferredDataSource(source)
                }
            } else {
                try audio.setPreferredInput(nil)
                captureSession.automaticallyConfiguresApplicationAudioSession = true
            }
            return true
        } catch {
            release(captureSession: captureSession)
            throw error
        }
    }

    /// The audio session is already active. Do not change category, activation, or the capture graph.
    static func changeInputWhileRecording(_ selection: VideoMicrophoneSelection,
                                          cameraPosition: AVCaptureDevice.Position,
                                          captureSession: AVCaptureSession) throws -> VideoMicrophoneSelection {
        let audio = AVAudioSession.sharedInstance()
        let ports = audio.availableInputs ?? []
        let descriptions = ports.map {
            VideoMicrophone(id: $0.uid, name: $0.portName, isBuiltIn: $0.portType == .builtInMic)
        }
        let selectedID = selection.resolvedInput(in: descriptions)?.id
        let port = ports.first { $0.uid == selectedID }
        if let port {
            try audio.setPreferredInput(port)
            if port.portType == .builtInMic, let sources = port.dataSources, !sources.isEmpty {
                let orientation: AVAudioSession.Orientation = cameraPosition == .front ? .front : .back
                try port.setPreferredDataSource(sources.first { $0.orientation == orientation })
            }
            captureSession.automaticallyConfiguresApplicationAudioSession = false
            return selection
        }
        try audio.setPreferredInput(nil)
        for port in ports where port.portType == .builtInMic && port.dataSources?.isEmpty == false {
            try port.setPreferredDataSource(nil)
        }
        captureSession.automaticallyConfiguresApplicationAudioSession = true
        return .automatic
    }

    static func release(captureSession: AVCaptureSession) {
        let audio = AVAudioSession.sharedInstance()
        defer {
            do { try audio.setActive(false, options: .notifyOthersOnDeactivation) }
            catch { logger.error("Couldn't deactivate video audio: \(error.localizedDescription, privacy: .public)") }
            captureSession.automaticallyConfiguresApplicationAudioSession = true
        }
        do {
            try audio.setPreferredInput(nil)
            for port in audio.availableInputs ?? []
                where port.portType == .builtInMic && port.dataSources?.isEmpty == false {
                try port.setPreferredDataSource(nil)
            }
        } catch {
            logger.error("Couldn't release video audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static var bluetoothOptions: AVAudioSession.CategoryOptions {
        if #available(iOS 26.0, *) { return [.allowBluetoothHFP, .bluetoothHighQualityRecording] }
        return [.allowBluetoothHFP]
    }
}
