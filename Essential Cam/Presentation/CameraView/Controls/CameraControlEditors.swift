//
//  CameraControlEditors.swift
//  Essential Cam
//
//  Created by Codex on 27/09/26.
//

import SwiftUI

struct ExposureControlEditor: View {
    let controls: CameraControlsController
    let dismiss: () -> Void

    var body: some View {
        CameraControlEditorContainer(
            width: mode == .manual ? 108 : 50,
            accessibilityLabel: "Close exposure control",
            dismiss: dismiss
        ) {
            modeMenu
            CameraControlEditorSeparator()

            Group {
                switch mode {
                case .automatic:
                    CameraValueDial(
                        value: exposureBias,
                        range: controls.exposureBiasRange,
                        step: 0.1,
                        title: "EV",
                        orientation: .vertical,
                        neutralValue: 0,
                        showsBackground: false
                    )
                    .frame(width: 50, height: 280)
                case .manual:
                    manualDials
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: mode)
    }

    private var modeMenu: some View {
        CameraControlModeMenu(
            mode: mode,
            accessibilityLabel: "Exposure mode",
            useAutomatic: controls.useAutomaticExposure,
            useManual: controls.useManualExposure
        )
    }

    private var manualDials: some View {
        HStack(spacing: 8) {
            CameraValueDial(
                value: manualISOStops,
                range: isoStopsRange,
                step: 1 / 3,
                title: "ISO",
                orientation: .vertical,
                valueFormatter: formatISO,
                showsBackground: false
            )
            .frame(width: 50, height: 280)

            CameraValueDial(
                value: manualDurationStops,
                range: durationStopsRange,
                step: 1 / 3,
                title: "SHUT",
                orientation: .vertical,
                valueFormatter: formatShutterSpeed,
                showsBackground: false
            )
            .frame(width: 50, height: 280)
        }
    }

    private var exposureBias: Binding<Double> {
        Binding(
            get: { Double(controls.settings.exposure.exposureBias ?? 0) },
            set: { controls.setExposureBias(Float($0)) }
        )
    }

    private var manualISOStops: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(iso, _) = controls.settings.exposure else {
                    return isoStopsRange.lowerBound
                }
                return log2(Double(iso))
            },
            set: { controls.setManualExposureISO(Float(pow(2, $0))) }
        )
    }

    private var manualDurationStops: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(_, duration) = controls.settings.exposure else {
                    return durationStopsRange.lowerBound
                }
                return log2(duration)
            },
            set: { controls.setManualExposureDuration(pow(2, $0)) }
        )
    }

    private var isoStopsRange: ClosedRange<Double> {
        log2(controls.exposureISORange.lowerBound)...log2(controls.exposureISORange.upperBound)
    }

    private var durationStopsRange: ClosedRange<Double> {
        log2(controls.exposureDurationRange.lowerBound)...log2(controls.exposureDurationRange.upperBound)
    }

    private var mode: CameraControlEditorMode {
        switch controls.settings.exposure {
        case .automatic: .automatic
        case .manual: .manual
        }
    }

    private func formatISO(_ stops: Double) -> String {
        String(Int(pow(2, stops).rounded()))
    }

    private func formatShutterSpeed(_ stops: Double) -> String {
        let duration = pow(2, stops)
        if duration >= 1 {
            return duration.formatted(
                .number.precision(.fractionLength(duration < 10 ? 1 : 0))
            ) + "s"
        }
        return "1/\(Int((1 / duration).rounded()))"
    }
}

struct FocusControlEditor: View {
    let controls: CameraControlsController
    let dismiss: () -> Void

    var body: some View {
        CameraControlEditorContainer(
            width: 50,
            accessibilityLabel: "Close focus control",
            dismiss: dismiss
        ) {
            CameraControlModeMenu(
                mode: mode,
                accessibilityLabel: "Focus mode",
                automaticEnabled: controls.supportsAutomaticFocus,
                manualEnabled: controls.supportsManualFocus,
                useAutomatic: controls.useAutomaticFocus,
                useManual: controls.useManualFocus
            )

            if mode == .manual {
                CameraControlEditorSeparator()
                CameraValueDial(
                    value: manualFocusPosition,
                    range: 0...1,
                    step: 0.01,
                    title: "FOCUS",
                    orientation: .vertical,
                    valueFormatter: formatFocusPosition,
                    showsBackground: false
                )
                .frame(width: 50, height: 280)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: mode)
    }

    private var manualFocusPosition: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(lensPosition) = controls.settings.focus else {
                    return 0.5
                }
                return Double(lensPosition)
            },
            set: { controls.setManualFocusLensPosition(Float($0)) }
        )
    }

    private var mode: CameraControlEditorMode {
        switch controls.settings.focus {
        case .manual: .manual
        case .auto, .continuousAuto, .locked: .automatic
        }
    }

    private func formatFocusPosition(_ position: Double) -> String {
        switch position {
        case 0: "NEAR"
        case 1: "FAR"
        default: "\(Int((position * 100).rounded()))%"
        }
    }
}

struct WhiteBalanceControlEditor: View {
    let controls: CameraControlsController
    let dismiss: () -> Void

    var body: some View {
        CameraControlEditorContainer(
            width: mode == .manual ? 108 : 50,
            accessibilityLabel: "Close white balance control",
            dismiss: dismiss
        ) {
            CameraControlModeMenu(
                mode: mode,
                accessibilityLabel: "White balance mode",
                automaticEnabled: controls.supportsAutomaticWhiteBalance,
                manualEnabled: controls.supportsManualWhiteBalance,
                useAutomatic: controls.useAutomaticWhiteBalance,
                useManual: controls.useManualWhiteBalance
            )

            if mode == .manual {
                CameraControlEditorSeparator()
                manualDials
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: mode)
    }

    private var manualDials: some View {
        HStack(spacing: 8) {
            CameraValueDial(
                value: temperature,
                range: controls.whiteBalanceTemperatureRange,
                step: 100,
                title: "TEMP",
                orientation: .vertical,
                valueFormatter: { "\(Int($0.rounded()))K" },
                showsBackground: false
            )
            .frame(width: 50, height: 280)

            CameraValueDial(
                value: tint,
                range: controls.whiteBalanceTintRange,
                step: 1,
                title: "TINT",
                orientation: .vertical,
                neutralValue: 0,
                valueFormatter: formatTint,
                showsBackground: false
            )
            .frame(width: 50, height: 280)
        }
    }

    private var temperature: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(temperature, _) = controls.settings.whiteBalance else {
                    return 5_500
                }
                return Double(temperature)
            },
            set: { controls.setManualWhiteBalanceTemperature(Float($0)) }
        )
    }

    private var tint: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(_, tint) = controls.settings.whiteBalance else {
                    return 0
                }
                return Double(tint)
            },
            set: { controls.setManualWhiteBalanceTint(Float($0)) }
        )
    }

    private var mode: CameraControlEditorMode {
        switch controls.settings.whiteBalance {
        case .manual: .manual
        case .auto, .continuousAuto, .locked: .automatic
        }
    }

    private func formatTint(_ tint: Double) -> String {
        let value = Int(tint.rounded())
        return value > 0 ? "+\(value)" : "\(value)"
    }
}

private struct CameraControlEditorContainer<Content: View>: View {
    let width: CGFloat
    let accessibilityLabel: String
    let dismiss: () -> Void
    let content: Content

    init(
        width: CGFloat,
        accessibilityLabel: String,
        dismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.accessibilityLabel = accessibilityLabel
        self.dismiss = dismiss
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                content
            }
            .frame(width: width)
            .cameraControlBackground(cornerRadius: 16)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .cameraControlCircleBackground()
            .accessibilityLabel(accessibilityLabel)
        }
        .padding(.trailing, 8)
    }
}

private struct CameraControlModeMenu: View {
    let mode: CameraControlEditorMode
    let accessibilityLabel: String
    var automaticEnabled = true
    var manualEnabled = true
    let useAutomatic: () -> Void
    let useManual: () -> Void

    var body: some View {
        Menu {
            Button(action: useAutomatic) {
                settingLabel("Automatic", isSelected: mode == .automatic)
            }
            .disabled(!automaticEnabled)

            Button(action: useManual) {
                settingLabel("Manual", isSelected: mode == .manual)
            }
            .disabled(!manualEnabled)
        } label: {
            HStack(spacing: 2) {
                Text(mode.displayName)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func settingLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}

private struct CameraControlEditorSeparator: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.7))
            .frame(height: 1)
            .padding(.horizontal, 8)
    }
}

private enum CameraControlEditorMode: Equatable {
    case automatic
    case manual

    var displayName: String {
        switch self {
        case .automatic: "AUTO"
        case .manual: "MAN"
        }
    }
}
