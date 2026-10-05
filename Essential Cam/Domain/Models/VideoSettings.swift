//
//  VideoSettings.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Foundation

struct VideoSettings: Codable, Equatable, Sendable {
    var resolution: VideoResolution = .fullHD
    var frameRate: VideoFrameRate = .fps30
    var codec: VideoCodec = .h264
    var stabilization: VideoStabilization = .standard
    var torch: Bool = false
    var microphone: VideoMicrophoneSelection = .automatic

    static let standard = VideoSettings()

    init(resolution: VideoResolution = .fullHD, frameRate: VideoFrameRate = .fps30,
         codec: VideoCodec = .h264, stabilization: VideoStabilization = .standard,
         torch: Bool = false, microphone: VideoMicrophoneSelection = .automatic) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.stabilization = stabilization
        self.torch = torch
        self.microphone = microphone
    }

    private enum CodingKeys: String, CodingKey {
        case resolution, frameRate, codec, stabilization, torch, microphone
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        resolution = try values.decodeIfPresent(VideoResolution.self, forKey: .resolution) ?? .fullHD
        frameRate = try values.decodeIfPresent(VideoFrameRate.self, forKey: .frameRate) ?? .fps30
        codec = try values.decodeIfPresent(VideoCodec.self, forKey: .codec) ?? .h264
        stabilization = try values.decodeIfPresent(VideoStabilization.self, forKey: .stabilization) ?? .standard
        torch = try values.decodeIfPresent(Bool.self, forKey: .torch) ?? false
        microphone = try values.decodeIfPresent(VideoMicrophoneSelection.self, forKey: .microphone) ?? .automatic
    }
}

enum VideoMicrophoneSelection: Codable, Hashable, Sendable {
    case automatic
    case iPhone
    case external(id: String, name: String)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.automatic, .automatic), (.iPhone, .iPhone): true
        case let (.external(left, _), .external(right, _)): left == right
        default: false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .automatic: hasher.combine(0)
        case .iPhone: hasher.combine(1)
        case let .external(id, _): hasher.combine(2); hasher.combine(id)
        }
    }

    func resolvedInput(in inputs: [VideoMicrophone]) -> VideoMicrophone? {
        switch self {
        case .automatic: nil
        case .iPhone: inputs.first { $0.isBuiltIn }
        case let .external(id, _): inputs.first { !$0.isBuiltIn && $0.id == id }
        }
    }

    func isUnavailable(in inputs: [VideoMicrophone]) -> Bool {
        self != .automatic && resolvedInput(in: inputs) == nil
    }
}

/// Session-only selection history. Saved presets are never changed by route loss.
struct VideoMicrophoneFallbackHistory {
    private var previous: [VideoMicrophoneSelection] = []

    mutating func rememberChange(from old: VideoMicrophoneSelection, to new: VideoMicrophoneSelection) {
        guard old != new else { return }
        previous.removeAll { $0 == old || $0 == new }
        previous.append(old)
        if previous.count > 10 { previous.removeFirst(previous.count - 10) }
    }

    func fallback(for selection: VideoMicrophoneSelection, inputs: [VideoMicrophone]) -> VideoMicrophoneSelection? {
        guard selection.isUnavailable(in: inputs) else { return nil }
        return previous.reversed().first { $0 != selection && !$0.isUnavailable(in: inputs) } ?? .automatic
    }
}

struct VideoMicrophone: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let isBuiltIn: Bool
    var selection: VideoMicrophoneSelection {
        isBuiltIn ? .iPhone : .external(id: id, name: name)
    }
}

enum VideoResolution: String, Codable, CaseIterable, Sendable {
    case fullHD, ultraHD
    var width: Int32 { self == .fullHD ? 1920 : 3840 }
    var height: Int32 { self == .fullHD ? 1080 : 2160 }
}

enum VideoFrameRate: Int32, Codable, CaseIterable, Sendable {
    case fps24 = 24, fps25 = 25, fps30 = 30, fps50 = 50, fps60 = 60
}

enum VideoCodec: String, Codable, CaseIterable, Sendable { case h264, hevc }
enum VideoStabilization: String, Codable, CaseIterable, Sendable {
    case off, standard, cinematic, cinematicExtended
}

struct VideoConfiguration: Hashable, Sendable {
    let resolution: VideoResolution
    let frameRate: VideoFrameRate
}

struct VideoCapabilities: Sendable {
    var configurations: [VideoConfiguration] = []
    var codecs: [VideoCodec] = []
    var stabilizations: [VideoStabilization] = [.off]
    var supportsTorch = false
    var microphones: [VideoMicrophone] = []

    func resolved(_ requested: VideoSettings) -> VideoSettings? {
        guard let configuration = configurations.first(where: {
            $0.resolution == requested.resolution && $0.frameRate == requested.frameRate
        }) ?? configurations.first(where: {
            $0.resolution == requested.resolution && $0.frameRate == .fps30
        }) ?? configurations.first(where: { $0.resolution == requested.resolution })
            ?? configurations.first(where: { $0.resolution == .fullHD && $0.frameRate == .fps30 })
            ?? configurations.first, let codec = codecs.contains(requested.codec) ? requested.codec : codecs.first else {
            return nil
        }
        var result = requested
        result.resolution = configuration.resolution
        result.frameRate = configuration.frameRate
        result.codec = codec
        if !stabilizations.contains(result.stabilization) { result.stabilization = .off }
        if !supportsTorch { result.torch = false }
        return result
    }
}

/// Session-only profiles. Camera values are deliberately not persisted.
struct CaptureSettingsProfiles {
    private(set) var photo = CameraSettings.standard
    private(set) var video = CameraSettings.standard(for: .video)

    subscript(mode: CaptureMode) -> CameraSettings {
        get { mode == .photo ? photo : video }
        set {
            var value = newValue
            value.captureMode = mode
            if mode == .photo { photo = value } else { video = value }
        }
    }
}
