//
//  CameraPresetsView.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import SwiftUI

struct CameraPresetsView: View {
    let store: CameraPresetStore
    let controls: CameraControlsController
    var photoResolutions: [PhotoResolution] = []

    @State private var isCreatingPreset = false

    var body: some View {
        List {
            if let error = store.persistenceErrorDescription {
                Section("Presets Couldn't Be Saved or Loaded") {
                    Text(error).font(.footnote)
                    Text("Your existing preset file has been preserved.").font(.footnote)
                }
            }
            ForEach(Array(store.modePresets.enumerated()), id: \.element.id) { index, preset in
                NavigationLink {
                    CameraPresetEditorView(
                        preset: preset,
                        controls: controls,
                        photoResolutions: photoResolutions,
                        save: store.save,
                        delete: { store.delete(id: preset.id) }
                    )
                } label: {
                    CameraPresetRow(index: index + 1, preset: preset)
                }
            }
            .onMove(perform: store.move)
        }
        .overlay {
            if store.modePresets.isEmpty {
                ContentUnavailableView {
                    Label("No Presets", systemImage: "camera.filters")
                } description: {
                    Text("Create a preset to save a reusable \(controls.captureMode.accessibilityName.lowercased()) configuration.")
                } actions: {
                    Button("Create Preset") { isCreatingPreset = true }
                }
            }
        }
        .navigationTitle("\(controls.captureMode.accessibilityName) Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.modePresets.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") {
                    isCreatingPreset = true
                }
            }
        }
        .navigationDestination(isPresented: $isCreatingPreset) {
            CameraPresetEditorView(
                preset: nil,
                controls: controls,
                photoResolutions: photoResolutions,
                save: store.save,
                delete: nil
            )
        }
    }
}

private struct CameraPresetRow: View {
    let index: Int
    let preset: CameraPreset

    var body: some View {
        HStack(spacing: 12) {
            Text(index.formatted())
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name)
                    .font(.body)
                Text(preset.settings.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct CameraPresetEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let controls: CameraControlsController
    let photoResolutions: [PhotoResolution]
    let save: (CameraPreset) -> Void
    let delete: (() -> Void)?

    @State private var draft: CameraPreset
    @State private var original: CameraPreset
    @State private var presentedAlert: PresentedAlert?

    init(
        preset: CameraPreset?,
        controls: CameraControlsController,
        photoResolutions: [PhotoResolution],
        save: @escaping (CameraPreset) -> Void,
        delete: (() -> Void)?
    ) {
        let initialPreset = preset ?? CameraPreset(
            name: "",
            settings: CameraPresetSettings(settings: controls.settings)
        )
        self.controls = controls
        self.photoResolutions = photoResolutions
        self.save = save
        self.delete = delete
        _draft = State(initialValue: initialPreset)
        _original = State(initialValue: initialPreset)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Preset Name", text: $draft.name)
                    .textInputAutocapitalization(.words)
            }

            Section {
                Button {
                    if draft.settings != original.settings {
                        presentedAlert = .replaceWithCurrentSettings
                    } else {
                        fillWithCurrentSettings()
                    }
                } label: {
                    Label("Use Current Camera Settings", systemImage: "camera.fill")
                }
            } header: {
                Text("Starting Values")
            } footer: {
                Text("This replaces the preset values without changing the active camera configuration.")
            }

            if draft.captureMode == .photo { aspectRatioSection }
            exposureSection
            focusSection
            whiteBalanceSection
            if draft.captureMode == .photo {
                flashSection
                photoSettingsSection
            } else {
                Section("Video") {
                    VideoSettingsEditor(settings: Binding(
                        get: { draft.settings.video ?? .standard },
                        set: { value in
                            var adjusted = value
                            let rates = controls.videoCapabilities.configurations.filter { $0.resolution == value.resolution }
                            if !rates.contains(where: { $0.frameRate == value.frameRate }), let fallback = rates.first {
                                adjusted.frameRate = fallback.frameRate
                            }
                            draft.settings.video = adjusted
                        }
                    ), capabilities: controls.videoCapabilities)
                }
            }

            if delete != nil {
                Section {
                    Button("Delete Preset", role: .destructive) {
                        presentedAlert = .deletePreset
                    }
                }
            }
        }
        .navigationTitle(original.name.isEmpty ? "New Preset" : "Edit Preset")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    requestDismissal()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: savePreset)
                    .disabled(trimmedName.isEmpty || !hasChanges)
            }
        }
        .alert(item: $presentedAlert, content: alert)
    }

    private var aspectRatioSection: some View {
        Section("Aspect Ratio") {
            Picker("Aspect Ratio", selection: aspectRatio) {
                ForEach(CameraAspectRatio.allCases, id: \.self) { ratio in
                    Text(ratio.displayName).tag(ratio)
                }
            }
            .pickerStyle(.segmented)
            resetButton(for: \.aspectRatio)
        }
    }

    private var exposureSection: some View {
        Section("Exposure") {
            Picker("Mode", selection: exposureMode) {
                ForEach(PresetControlMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch resolvedExposure {
            case .automatic:
                Slider(
                    value: exposureBias,
                    in: controls.exposureBiasRange,
                    step: 0.1
                )
                Text("\(Float(exposureBias.wrappedValue).exposureBiasDisplayName) EV")
                    .foregroundStyle(.secondary)
            case .manual:
                Slider(value: manualISO, in: controls.exposureISORange)
                Text("ISO \(Int(manualISO.wrappedValue.rounded()))")
                    .foregroundStyle(.secondary)
                Slider(value: manualDurationStops, in: exposureDurationStopsRange)
                Text(manualDurationName)
                    .foregroundStyle(.secondary)
            }

            resetButton(for: \.exposure)
        }
    }

    private var focusSection: some View {
        Section("Focus") {
            Picker("Mode", selection: focusMode) {
                ForEach(PresetControlMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if case .manual = resolvedFocus {
                Slider(value: manualFocus, in: 0...1, step: 0.01)
                Text("\(Int((manualFocus.wrappedValue * 100).rounded()))%")
                    .foregroundStyle(.secondary)
            }

            resetButton(for: \.focus)
        }
    }

    private var whiteBalanceSection: some View {
        Section("White Balance") {
            Picker("Mode", selection: whiteBalanceMode) {
                ForEach(PresetControlMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if case .manual = resolvedWhiteBalance {
                Slider(
                    value: whiteBalanceTemperature,
                    in: controls.whiteBalanceTemperatureRange,
                    step: 100
                )
                Text("\(Int(whiteBalanceTemperature.wrappedValue.rounded())) K")
                    .foregroundStyle(.secondary)
                Slider(
                    value: whiteBalanceTint,
                    in: controls.whiteBalanceTintRange,
                    step: 1
                )
                Text("Tint \(Int(whiteBalanceTint.wrappedValue.rounded()))")
                    .foregroundStyle(.secondary)
            }

            resetButton(for: \.whiteBalance)
        }
    }

    private var flashSection: some View {
        Section("Flash") {
            Picker("Flash", selection: flashMode) {
                Text("Off").tag(CameraFlashMode.off)
                Text("On").tag(CameraFlashMode.on)
                Text("Automatic").tag(CameraFlashMode.automatic)
            }
            resetButton(for: \.flashMode)
        }
    }

    private var photoSettingsSection: some View {
        Section("Photo Output") {
            Picker("Image Format", selection: Binding(
                get: { draft.settings.photoOutputFormat }, set: { draft.settings.photoOutputFormat = $0 }
            )) {
                Text("Keep Current").tag(PhotoOutputFormat?.none)
                ForEach(PhotoOutputFormat.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
            }
            Picker("Resolution", selection: Binding(
                get: { draft.settings.photoResolution }, set: { draft.settings.photoResolution = $0 }
            )) {
                Text("Keep Current").tag(PhotoResolution?.none)
                ForEach(photoResolutions, id: \.self) { Text($0.megapixelDisplayName).tag(Optional($0)) }
            }
            Picker("Timer", selection: Binding(
                get: { draft.settings.photoTimer }, set: { draft.settings.photoTimer = $0 }
            )) {
                Text("Keep Current").tag(PhotoTimer?.none)
                ForEach(PhotoTimer.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
            }
            Picker("Content-Aware Correction", selection: Binding(
                get: { draft.settings.contentAwareCorrection }, set: { draft.settings.contentAwareCorrection = $0 }
            )) {
                Text("Keep Current").tag(ContentAwareCorrection?.none)
                ForEach(ContentAwareCorrection.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
            }
        }
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        draft != original
    }

    private var resolvedExposure: ExposureSetting {
        draft.settings.exposure ?? CameraSettings.standard.exposure
    }

    private var resolvedFocus: FocusSetting {
        draft.settings.focus ?? CameraSettings.standard.focus
    }

    private var resolvedWhiteBalance: WhiteBalanceSetting {
        draft.settings.whiteBalance ?? CameraSettings.standard.whiteBalance
    }

    private var aspectRatio: Binding<CameraAspectRatio> {
        Binding(
            get: { draft.settings.aspectRatio ?? CameraSettings.standard.aspectRatio },
            set: { draft.settings.aspectRatio = $0 }
        )
    }

    private var flashMode: Binding<CameraFlashMode> {
        Binding(
            get: { draft.settings.flashMode ?? CameraSettings.standard.flashMode },
            set: { draft.settings.flashMode = $0 }
        )
    }

    private var exposureMode: Binding<PresetControlMode> {
        Binding(
            get: {
                if case .manual = resolvedExposure { return .manual }
                return .automatic
            },
            set: { mode in
                switch mode {
                case .automatic:
                    draft.settings.exposure = .automatic(exposureBias: 0)
                case .manual:
                    draft.settings.exposure = .manual(
                        iso: Float(clamped(100, to: controls.exposureISORange)),
                        durationInSeconds: clamped(
                            1.0 / 125.0,
                            to: controls.exposureDurationRange
                        )
                    )
                }
            }
        )
    }

    private var exposureBias: Binding<Double> {
        Binding(
            get: {
                guard case let .automatic(bias) = resolvedExposure else { return 0 }
                return Double(bias)
            },
            set: { draft.settings.exposure = .automatic(exposureBias: Float($0)) }
        )
    }

    private var manualISO: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(iso, _) = resolvedExposure else {
                    return controls.exposureISORange.lowerBound
                }
                return Double(iso)
            },
            set: { value in
                guard case let .manual(_, duration) = resolvedExposure else { return }
                draft.settings.exposure = .manual(
                    iso: Float(value),
                    durationInSeconds: duration
                )
            }
        )
    }

    private var manualDurationStops: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(_, duration) = resolvedExposure else {
                    return exposureDurationStopsRange.lowerBound
                }
                return log2(duration)
            },
            set: { value in
                guard case let .manual(iso, _) = resolvedExposure else { return }
                draft.settings.exposure = .manual(
                    iso: iso,
                    durationInSeconds: pow(2, value)
                )
            }
        )
    }

    private var exposureDurationStopsRange: ClosedRange<Double> {
        log2(controls.exposureDurationRange.lowerBound)...log2(controls.exposureDurationRange.upperBound)
    }

    private var manualDurationName: String {
        let duration = pow(2, manualDurationStops.wrappedValue)
        return duration >= 1
            ? duration.formatted(.number.precision(.fractionLength(0...1))) + " s"
            : "1/\(Int((1 / duration).rounded())) s"
    }

    private var focusMode: Binding<PresetControlMode> {
        Binding(
            get: {
                if case .manual = resolvedFocus { return .manual }
                return .automatic
            },
            set: { mode in
                draft.settings.focus = mode == .automatic
                    ? .continuousAuto
                    : .manual(lensPosition: 0.5)
            }
        )
    }

    private var manualFocus: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(position) = resolvedFocus else { return 0.5 }
                return Double(position)
            },
            set: { draft.settings.focus = .manual(lensPosition: Float($0)) }
        )
    }

    private var whiteBalanceMode: Binding<PresetControlMode> {
        Binding(
            get: {
                if case .manual = resolvedWhiteBalance { return .manual }
                return .automatic
            },
            set: { mode in
                draft.settings.whiteBalance = mode == .automatic
                    ? .continuousAuto
                    : .manual(temperature: 5_500, tint: 0)
            }
        )
    }

    private var whiteBalanceTemperature: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(temperature, _) = resolvedWhiteBalance else {
                    return 5_500
                }
                return Double(temperature)
            },
            set: { value in
                guard case let .manual(_, tint) = resolvedWhiteBalance else { return }
                draft.settings.whiteBalance = .manual(
                    temperature: Float(value),
                    tint: tint
                )
            }
        )
    }

    private var whiteBalanceTint: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(_, tint) = resolvedWhiteBalance else { return 0 }
                return Double(tint)
            },
            set: { value in
                guard case let .manual(temperature, _) = resolvedWhiteBalance else { return }
                draft.settings.whiteBalance = .manual(
                    temperature: temperature,
                    tint: Float(value)
                )
            }
        )
    }

    private func resetButton<Value>(
        for keyPath: WritableKeyPath<CameraPresetSettings, Value?>
    ) -> some View {
        Button("Use Default") {
            draft.settings[keyPath: keyPath] = nil
        }
        .font(.subheadline)
    }

    private func fillWithCurrentSettings() {
        draft.settings = CameraPresetSettings(settings: controls.settings)
    }

    private func savePreset() {
        draft.name = trimmedName
        save(draft)
        original = draft
        dismiss()
    }

    private func requestDismissal() {
        if hasChanges {
            presentedAlert = .discardChanges
        } else {
            dismiss()
        }
    }

    private func alert(for alert: PresentedAlert) -> Alert {
        switch alert {
        case .discardChanges:
            Alert(
                title: Text("Discard Changes?"),
                message: Text("Your unsaved changes will be lost."),
                primaryButton: .destructive(Text("Discard"), action: dismiss.callAsFunction),
                secondaryButton: .cancel()
            )
        case .deletePreset:
            Alert(
                title: Text("Delete Preset?"),
                message: Text("This preset will be removed."),
                primaryButton: .destructive(Text("Delete")) {
                    delete?()
                    dismiss()
                },
                secondaryButton: .cancel()
            )
        case .replaceWithCurrentSettings:
            Alert(
                title: Text("Replace Preset Values?"),
                message: Text("The settings you edited will be replaced with the current camera values."),
                primaryButton: .default(Text("Replace"), action: fillWithCurrentSettings),
                secondaryButton: .cancel()
            )
        }
    }

    private func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private enum PresetControlMode: CaseIterable {
    case automatic
    case manual

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .manual: "Manual"
        }
    }
}

private enum PresentedAlert: Identifiable {
    case discardChanges
    case deletePreset
    case replaceWithCurrentSettings

    var id: Self { self }
}

private extension CameraPresetSettings {
    var summary: String {
        let exposureName: String
        switch exposure ?? CameraSettings.standard.exposure {
        case let .automatic(bias):
            exposureName = "Auto \(bias.exposureBiasDisplayName) EV"
        case let .manual(iso, duration):
            let shutter = duration >= 1
                ? duration.formatted(.number.precision(.fractionLength(0...1))) + " s"
                : "1/\(Int((1 / duration).rounded()))"
            exposureName = "\(shutter) · ISO \(Int(iso.rounded()))"
        }

        let whiteBalanceName: String
        switch whiteBalance ?? CameraSettings.standard.whiteBalance {
        case let .manual(temperature, _):
            whiteBalanceName = "\(Int(temperature.rounded())) K"
        case .auto, .continuousAuto, .locked:
            whiteBalanceName = "Auto WB"
        }

        if captureMode == .video {
            let values = video ?? .standard
            return "\(exposureName) · \(values.resolution.displayName) · \(values.frameRate.displayName) · \(values.codec.shortName)"
        }
        let ratio = (aspectRatio ?? CameraSettings.standard.aspectRatio).displayName
        return "\(exposureName) · \(whiteBalanceName) · \(ratio)"
    }
}
