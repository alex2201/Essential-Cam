//
//  CameraSettingsView.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import SwiftUI

struct CameraSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let viewModel: CameraViewModel
    @State private var isClosing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CaptureProfileSettingsView(mode: .photo, close: close, viewModel: viewModel)
                    } label: {
                        Label("Photo Settings", systemImage: "camera")
                    }
                    .accessibilityIdentifier("settings.photo")
                    NavigationLink {
                        CaptureProfileSettingsView(mode: .video, close: close, viewModel: viewModel)
                    } label: {
                        Label("Video Settings", systemImage: "video")
                    }
                    .accessibilityIdentifier("settings.video")
                } header: {
                    Text("Capture Settings")
                } footer: {
                    Text("Edit either profile. Closing Settings returns to your original capture mode.")
                }

                Section("Composition") {
                    NavigationLink("Composition Guides") { CompositionGuidesSettingsView() }
                        .accessibilityIdentifier("settings.guides")
                }

                Section("Camera") {
                    NavigationLink("Lens") { LensSettingsView(viewModel: viewModel) }
                    NavigationLink("Camera") { CameraPositionSettingsView(viewModel: viewModel) }
                }
                Section {
                    NavigationLink("Feedback") { FeedbackView() }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close)
                        .disabled(isClosing || viewModel.controls.isApplyingConfiguration)
                }
            }
            .disabled(isClosing || viewModel.controls.isApplyingConfiguration)
        }
        .disabled(isClosing)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.controls.monitorVideoMicrophones()
        }
        .onAppear { viewModel.beginSettingsEditing() }
        .onDisappear {
            Task { await viewModel.endSettingsEditing() }
        }
    }

    private func close() {
        isClosing = true
        Task {
            await viewModel.endSettingsEditing()
            dismiss()
        }
    }
}

private struct CaptureProfileSettingsView: View {
    let mode: CaptureMode
    let close: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(CameraPresetStore.self) private var presetStore
    let viewModel: CameraViewModel

    var body: some View {
        List {
            Section("Capture Controls") {
                settingsLink("Exposure", value: viewModel.controls.settings.exposure.settingsDisplayName) {
                    ExposureSettingsView(controls: viewModel.controls)
                }
                settingsLink("Focus", value: viewModel.controls.settings.focus.settingsDisplayName) {
                    FocusSettingsView(controls: viewModel.controls)
                }
                settingsLink("White Balance", value: viewModel.controls.settings.whiteBalance.settingsDisplayName) {
                    WhiteBalanceSettingsView(controls: viewModel.controls)
                }
            }
            if viewModel.selectedCaptureMode == .photo {
                Section("Photo") {
                    settingsLink("Aspect Ratio", value: viewModel.controls.settings.aspectRatio.displayName) {
                        AspectRatioSettingsView(controls: viewModel.controls)
                    }
                    settingsLink("Image Format", value: viewModel.controls.settings.photoOutputFormat.displayName) {
                        PhotoFormatSettingsView(viewModel: viewModel)
                    }
                    settingsLink(
                        "Photo Resolution",
                        value: selectedPhotoResolutionName
                    ) {
                        PhotoResolutionSettingsView(viewModel: viewModel)
                    }
                    settingsLink("Timer", value: viewModel.controls.settings.photoTimer.displayName) {
                        PhotoTimerSettingsView(controls: viewModel.controls)
                    }
                    settingsLink(
                        "Content-Aware Correction",
                        value: viewModel.controls.settings.contentAwareCorrection.displayName
                    ) {
                        ContentAwareCorrectionSettingsView(controls: viewModel.controls)
                    }
                }

            } else {
                Section("Video") {
                    VideoSettingsEditor(settings: Binding(
                        get: { viewModel.controls.settings.video },
                        set: { viewModel.controls.setVideoSettings($0) }
                    ), capabilities: viewModel.controls.videoCapabilities)
                }
            }
            if let notice = viewModel.controls.configurationNotice {
                Section {
                    Text(notice)
                    Button("Dismiss") { viewModel.controls.clearConfigurationNotice() }
                }
            }

            Section("Personalization") {
                NavigationLink("Quick Settings") {
                    QuickSettingsCustomizationView()
                }
            }

            Section("Presets") {
                settingsLink(
                    "Camera Presets",
                    value: presetStore.modePresets.count.formatted()
                ) {
                    CameraPresetsView(
                        store: presetStore,
                        controls: viewModel.controls,
                        photoResolutions: viewModel.availablePhotoResolutions
                    )
                }
            }

            Section("Camera") {
                settingsLink("Zoom", value: viewModel.controls.settings.zoomFactor.settingsZoomName) {
                    ZoomSettingsView(controls: viewModel.controls)
                }
            }
        }
        .navigationTitle("\(mode.accessibilityName) Settings")
        .disabled(viewModel.controls.isApplyingConfiguration || viewModel.selectedCaptureMode != mode)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: close)
                    .disabled(viewModel.controls.isApplyingConfiguration)
            }
        }
        .task {
            await viewModel.selectCaptureMode(mode)
            if mode == .video { await viewModel.controls.refreshVideoMicrophones() }
        }
    }

    private var selectedPhotoResolutionName: String {
        guard let selected = viewModel.controls.settings.photoResolution else {
            return "Unavailable"
        }
        return selected.megapixelDisplayName
    }

    private func settingsLink<Destination: View>(
        _ title: String,
        value: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    Text(value).font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text(title)
                    Spacer()
                    Text(value).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .accessibilityIdentifier("settings.\(title)")
    }
}

private struct AspectRatioSettingsView: View {
    let controls: CameraControlsController

    var body: some View {
        SelectionList(
            title: "Aspect Ratio",
            values: CameraAspectRatio.allCases,
            selected: controls.settings.aspectRatio,
            label: \CameraAspectRatio.displayName,
            select: controls.setAspectRatio
        )
    }
}

private struct ExposureSettingsView: View {
    let controls: CameraControlsController

    var body: some View {
        Form {
            Section("Mode") {
                selectionButton("Automatic", selected: isAutomatic) {
                    controls.useAutomaticExposure()
                }
                selectionButton("Manual", selected: !isAutomatic) {
                    controls.useManualExposure()
                }
            }

            if isAutomatic {
                Section("Exposure Compensation") {
                    Slider(
                        value: Binding(
                            get: { Double(controls.settings.exposure.exposureBias ?? 0) },
                            set: { controls.setExposureBias(Float($0)) }
                        ),
                        in: controls.exposureBiasRange,
                        step: 0.1
                    )
                    Text((controls.settings.exposure.exposureBias ?? 0).exposureBiasDisplayName + " EV")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("ISO") {
                    Slider(value: iso, in: controls.exposureISORange)
                    Text("ISO \(Int(iso.wrappedValue.rounded()))")
                        .foregroundStyle(.secondary)
                }
                Section("Shutter Speed") {
                    Slider(value: durationStops, in: durationStopsRange)
                    Text(shutterSpeedName)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Exposure")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isAutomatic: Bool {
        if case .automatic = controls.settings.exposure { return true }
        return false
    }

    private var iso: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(iso, _) = controls.settings.exposure else { return controls.exposureISORange.lowerBound }
                return Double(iso)
            },
            set: { controls.setManualExposureISO(Float($0)) }
        )
    }

    private var durationStops: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(_, duration) = controls.settings.exposure else { return durationStopsRange.lowerBound }
                return log2(duration)
            },
            set: { controls.setManualExposureDuration(pow(2, $0)) }
        )
    }

    private var durationStopsRange: ClosedRange<Double> {
        log2(controls.exposureDurationRange.lowerBound)...log2(controls.exposureDurationRange.upperBound)
    }

    private var shutterSpeedName: String {
        let duration = pow(2, durationStops.wrappedValue)
        return duration >= 1
            ? duration.formatted(.number.precision(.fractionLength(0...1))) + " s"
            : "1/\(Int((1 / duration).rounded())) s"
    }
}

private struct FocusSettingsView: View {
    let controls: CameraControlsController

    var body: some View {
        Form {
            Section("Mode") {
                selectionButton("Automatic", selected: !isManual) {
                    controls.useAutomaticFocus()
                }
                .disabled(!controls.supportsAutomaticFocus)
                selectionButton("Manual", selected: isManual) {
                    controls.useManualFocus()
                }
                .disabled(!controls.supportsManualFocus)
            }

            if isManual {
                Section("Lens Position") {
                    Slider(
                        value: Binding(
                            get: {
                                guard case let .manual(position) = controls.settings.focus else { return 0.5 }
                                return Double(position)
                            },
                            set: { controls.setManualFocusLensPosition(Float($0)) }
                        ),
                        in: 0...1,
                        step: 0.01
                    )
                    HStack {
                        Text("Near")
                        Spacer()
                        Text("Far")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isManual: Bool {
        if case .manual = controls.settings.focus { return true }
        return false
    }
}

private struct WhiteBalanceSettingsView: View {
    let controls: CameraControlsController

    var body: some View {
        Form {
            Section("Mode") {
                selectionButton("Automatic", selected: !isManual) {
                    controls.useAutomaticWhiteBalance()
                }
                .disabled(!controls.supportsAutomaticWhiteBalance)
                selectionButton("Manual", selected: isManual) {
                    controls.useManualWhiteBalance()
                }
                .disabled(!controls.supportsManualWhiteBalance)
            }

            if isManual {
                Section("Temperature") {
                    Slider(value: temperature, in: controls.whiteBalanceTemperatureRange, step: 100)
                    Text("\(Int(temperature.wrappedValue.rounded())) K")
                        .foregroundStyle(.secondary)
                }
                Section("Tint") {
                    Slider(value: tint, in: controls.whiteBalanceTintRange, step: 1)
                    Text("\(Int(tint.wrappedValue.rounded()))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("White Balance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isManual: Bool {
        if case .manual = controls.settings.whiteBalance { return true }
        return false
    }

    private var temperature: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(value, _) = controls.settings.whiteBalance else { return 5_500 }
                return Double(value)
            },
            set: { controls.setManualWhiteBalanceTemperature(Float($0)) }
        )
    }

    private var tint: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(_, value) = controls.settings.whiteBalance else { return 0 }
                return Double(value)
            },
            set: { controls.setManualWhiteBalanceTint(Float($0)) }
        )
    }
}

private struct LensSettingsView: View {
    let viewModel: CameraViewModel

    private var cameras: [Camera] {
        var result: [Camera] = []
        if let virtual = viewModel.preferredVirtualCamera { result.append(virtual) }
        result.append(contentsOf: viewModel.availableCameras.sorted {
            ($0.displayZoomFactor ?? .greatestFiniteMagnitude) < ($1.displayZoomFactor ?? .greatestFiniteMagnitude)
        })
        return result
    }

    var body: some View {
        List(cameras) { camera in
            selectionButton(camera.settingsDisplayName, selected: camera.id == viewModel.selectedCamera?.id) {
                viewModel.selectCamera(camera)
            }
        }
        .navigationTitle("Lens")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ZoomSettingsView: View {
    let controls: CameraControlsController

    var body: some View {
        Form {
            Section {
                Slider(
                    value: Binding(
                        get: { controls.settings.zoomFactor },
                        set: controls.setZoomFactor
                    ),
                    in: controls.zoomFactorRange
                )
                Text(controls.settings.zoomFactor.settingsZoomName)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("Available range: \(controls.zoomFactorRange.lowerBound.settingsZoomName)–\(controls.zoomFactorRange.upperBound.settingsZoomName)")
            }
        }
        .navigationTitle("Zoom")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CameraPositionSettingsView: View {
    let viewModel: CameraViewModel

    var body: some View {
        List {
            ForEach([Camera.Position.back, .front], id: \.settingsDisplayName) { position in
                selectionButton(position.settingsDisplayName, selected: position == viewModel.selectedCamera?.position) {
                    guard position != viewModel.selectedCamera?.position else { return }
                    viewModel.toggleCameraPosition()
                }
                .disabled(!viewModel.canSwitchCameraPosition || viewModel.isSwitchingCameraPosition)
            }
        }
        .navigationTitle("Camera")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PhotoFormatSettingsView: View {
    let viewModel: CameraViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.availablePhotoOutputFormats, id: \.self) { format in
                    selectionButton(format.displayName, selected: format == viewModel.controls.settings.photoOutputFormat) {
                        viewModel.controls.setPhotoOutputFormat(format)
                    }
                }
            } footer: {
                Text(viewModel.controls.settings.photoOutputFormat.description)
            }

            if viewModel.controls.settings.photoOutputFormat.isRAW {
                Section {
                    Label("RAW files preserve the full sensor frame. The selected aspect ratio only affects the camera preview.", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Image Format")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PhotoResolutionSettingsView: View {
    let viewModel: CameraViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.availablePhotoResolutions, id: \.self) { resolution in
                    selectionButton(
                        resolution.megapixelDisplayName,
                        selected: resolution == viewModel.controls.settings.photoResolution
                    ) {
                        viewModel.controls.setPhotoResolution(resolution)
                    }
                }
            } footer: {
                Text("The selected resolution is a maximum. The captured photo may use a lower resolution depending on the selected lens, lighting conditions, flash, and capture format.")
            }
        }
        .navigationTitle("Photo Resolution")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PhotoTimerSettingsView: View {
    let controls: CameraControlsController

    var body: some View {
        SelectionList(
            title: "Timer",
            values: PhotoTimer.allCases,
            selected: controls.settings.photoTimer,
            label: \PhotoTimer.displayName,
            select: controls.setPhotoTimer
        )
    }
}

private struct ContentAwareCorrectionSettingsView: View {
    let controls: CameraControlsController

    var body: some View {
        List {
            Section {
                ForEach(ContentAwareCorrection.allCases, id: \.self) { correction in
                    selectionButton(
                        correction.displayName,
                        selected: correction == controls.settings.contentAwareCorrection
                    ) {
                        controls.setContentAwareCorrection(correction)
                    }
                    .disabled(
                        correction == .automatic
                        && !controls.supportsContentAwareCorrection
                    )
                }
            } footer: {
                if controls.supportsContentAwareCorrection {
                    Text("Automatically corrects distortion around important subjects, such as faces near the edges. The final framing may differ slightly from the preview. This correction isn't applied to RAW photos.")
                } else {
                    Text("Content-aware correction isn't available for the selected camera configuration.")
                }
            }
        }
        .navigationTitle("Content-Aware Correction")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SelectionList<Value: Hashable>: View {
    let title: String
    let values: [Value]
    let selected: Value
    let label: KeyPath<Value, String>
    let select: (Value) -> Void

    var body: some View {
        List(values, id: \.self) { value in
            selectionButton(value[keyPath: label], selected: value == selected) {
                select(value)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func selectionButton(
    _ title: String,
    selected: Bool,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
    .accessibilityAddTraits(selected ? .isSelected : [])
}

private extension ExposureSetting {
    var settingsDisplayName: String {
        switch self {
        case let .automatic(bias): "Auto, \(bias.exposureBiasDisplayName) EV"
        case .manual: "Manual"
        }
    }
}

private extension FocusSetting {
    var settingsDisplayName: String {
        if case .manual = self { return "Manual" }
        return "Automatic"
    }
}

private extension WhiteBalanceSetting {
    var settingsDisplayName: String {
        if case .manual = self { return "Manual" }
        return "Automatic"
    }
}

private extension Camera {
    var settingsDisplayName: String {
        if case .virtual = deviceKind { return "Automatic Lens Selection" }
        if let focalLength = nominalFocalLengthIn35mmFilm {
            return "\(lens.settingsDisplayName) (\(Int(focalLength.rounded())) mm)"
        }
        return lens.settingsDisplayName
    }
}

private extension Camera.Lens {
    var settingsDisplayName: String {
        switch self {
        case .ultraWideAngle: "Ultra Wide"
        case .wideAngle: "Wide"
        case .telephoto: "Telephoto"
        case .unknown: "Camera Lens"
        }
    }
}

private extension Camera.Position {
    var settingsDisplayName: String {
        switch self {
        case .front: "Front"
        case .back: "Back"
        }
    }
}

private extension Double {
    var settingsZoomName: String {
        formatted(.number.precision(.fractionLength(0...1))) + "×"
    }
}

extension PhotoOutputFormat {
    var displayName: String {
        switch self {
        case .heif: "HEIF"
        case .jpeg: "JPEG"
        case .png: "PNG"
        case .tiff: "TIFF"
        case .raw: "RAW (DNG)"
        case .appleProRAW: "Apple ProRAW"
        }
    }

    var description: String {
        switch self {
        case .heif: "High-quality photos with efficient file sizes. Best for Apple devices."
        case .jpeg: "The most widely compatible photo format."
        case .png: "Lossless output with larger files."
        case .tiff: "High-quality lossless output with very large files."
        case .raw: "Minimally processed sensor data for maximum editing flexibility."
        case .appleProRAW: "Sensor data combined with Apple computational photography for professional editing."
        }
    }

}

extension PhotoResolution {
    var megapixelDisplayName: String {
        "\(Int(megapixels.rounded(.down))) MP"
    }
}

extension PhotoTimer {
    var displayName: String {
        self == .off ? "Off" : "\(rawValue) s"
    }
}

extension ContentAwareCorrection {
    var displayName: String {
        switch self {
        case .off: "Off"
        case .automatic: "Automatic"
        }
    }
}
