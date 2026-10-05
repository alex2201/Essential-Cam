//
//  VideoSettingsEditor.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import SwiftUI

struct VideoSettingsEditor: View {
    @Binding var settings: VideoSettings
    let capabilities: VideoCapabilities

    var body: some View {
        Picker("Resolution", selection: $settings.resolution) {
            ForEach(VideoResolution.allCases.filter { resolution in
                capabilities.configurations.contains { $0.resolution == resolution }
            }, id: \.self) { Text($0.displayName).tag($0) }
        }
        .accessibilityIdentifier("video.resolution")
        Picker("Frame Rate", selection: $settings.frameRate) {
            ForEach(VideoFrameRate.allCases.filter { fps in
                capabilities.configurations.contains { $0.resolution == settings.resolution && $0.frameRate == fps }
            }, id: \.self) { Text($0.displayName).tag($0) }
        }
        .accessibilityIdentifier("video.frameRate")
        Picker("Codec", selection: $settings.codec) {
            ForEach(capabilities.codecs, id: \.self) { Text($0.displayName).tag($0) }
        }
        .accessibilityIdentifier("video.codec")
        Picker("Stabilization", selection: $settings.stabilization) {
            ForEach(capabilities.stabilizations, id: \.self) { Text($0.displayName).tag($0) }
        }
        .accessibilityIdentifier("video.stabilization")
        if capabilities.supportsTorch {
            Toggle("Continuous Light", isOn: $settings.torch)
        }
        Picker("Microphone", selection: $settings.microphone) {
            Text("Automatic").tag(VideoMicrophoneSelection.automatic)
            Text("iPhone Microphone").tag(VideoMicrophoneSelection.iPhone)
            ForEach(capabilities.microphones.filter { !$0.isBuiltIn }) { input in
                Text(input.name).tag(input.selection)
            }
            if case let .external(_, name) = settings.microphone,
               settings.microphone.isUnavailable(in: capabilities.microphones) {
                Text("\(name) (Unavailable)").tag(settings.microphone)
            }
        }
        .accessibilityIdentifier("video.microphone")
        Text(settings.microphone.isUnavailable(in: capabilities.microphones)
             ? "The selected microphone is unavailable. Video will use the previous available selection or Automatic."
             : "Automatic lets iOS choose the microphone for your camera and connected devices. External inputs appear when recognized by iOS.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        Text("MOV · SDR · Microphone audio. Available options depend on the selected camera and format.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

struct VideoQuickSettingView: View {
    let control: QuickSettingControl
    let controls: CameraControlsController
    let dismiss: () -> Void

    var body: some View {
        switch control {
        case .videoResolution:
            QuickSettingSelectionView(title: control.title, icon: "video", values: controls.availableVideoResolutions,
                selectedValue: controls.settings.video.resolution, label: { $0.displayName },
                select: { value in update { $0.resolution = value } }, dismiss: dismiss)
        case .videoFrameRate:
            QuickSettingSelectionView(title: control.title, icon: "speedometer", values: controls.availableVideoFrameRates,
                selectedValue: controls.settings.video.frameRate, label: { $0.displayName },
                select: { value in update { $0.frameRate = value } }, dismiss: dismiss)
        case .videoCodec:
            QuickSettingSelectionView(title: control.title, icon: "film", values: controls.videoCapabilities.codecs,
                selectedValue: controls.settings.video.codec, label: { $0.shortName },
                select: { value in update { $0.codec = value } }, dismiss: dismiss)
        case .videoStabilization:
            QuickSettingSelectionView(title: control.title, icon: "hand.raised", values: controls.videoCapabilities.stabilizations,
                selectedValue: controls.settings.video.stabilization, label: { $0.displayName },
                select: { value in update { $0.stabilization = value } }, dismiss: dismiss)
        case .videoMicrophone:
            QuickSettingSelectionView(title: control.title, icon: "mic", values: microphoneSelections,
                selectedValue: controls.settings.video.microphone, label: { $0.displayName },
                select: { value in update { $0.microphone = value } }, dismiss: dismiss)
        case .videoTorch:
            QuickSettingSelectionView(title: control.title, icon: "flashlight.on.fill", values: [false, true],
                selectedValue: controls.settings.video.torch, label: { $0 ? "On" : "Off" },
                select: { value in update { $0.torch = value } }, dismiss: dismiss)
        default: EmptyView()
        }
    }

    private var microphoneSelections: [VideoMicrophoneSelection] {
        var choices: [VideoMicrophoneSelection] = [.automatic, .iPhone]
        choices += controls.videoCapabilities.microphones.filter { !$0.isBuiltIn }.map(\.selection)
        if !choices.contains(controls.settings.video.microphone) { choices.append(controls.settings.video.microphone) }
        return choices
    }

    private func update(_ change: (inout VideoSettings) -> Void) {
        var value = controls.settings.video
        change(&value)
        controls.setVideoSettings(value)
        dismiss()
    }
}
