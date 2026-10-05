//
//  CameraControlEditors.swift
//  Essential Cam
//
//  Created by Alexander López on 27/09/26.
//

import SwiftUI

struct ExposureControlEditor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

            ZStack {
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
                    .transition(.opacity)
                case .manual:
                    manualDials
                        .transition(.opacity)
                }
            }
            .frame(height: 280)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.4), value: mode)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                VStack(spacing: 4) {
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
                }
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.4), value: mode)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                VStack(spacing: 4) {
                    CameraControlEditorSeparator()
                    manualDials
                }
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.4), value: mode)
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
                    .cameraIconRotation()
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

/// Inline options keep camera mode choices oriented with the capture controls.
private struct CameraControlModeMenu: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cameraIconRotationDegrees) private var rotationDegrees
    @State private var isExpanded = false

    let mode: CameraControlEditorMode
    let accessibilityLabel: String
    var automaticEnabled = true
    var manualEnabled = true
    let useAutomatic: () -> Void
    let useManual: () -> Void

    private var isHorizontal: Bool { abs(rotationDegrees) == 90 }

    var body: some View {
        VStack(spacing: isExpanded ? 4 : 0) {
            Button {
                withAnimation(expansionAnimation) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(mode.displayName)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 60)
                .cameraControlContentRotation()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(mode == .automatic ? "Automatic" : "Manual")
            .accessibilityHint(isExpanded ? "Hides mode options" : "Shows mode options")

            VStack(spacing: 4) {
                modeOption(.automatic, title: "Automatic", enabled: automaticEnabled, action: useAutomatic)
                modeOption(.manual, title: "Manual", enabled: manualEnabled, action: useManual)
            }
            .frame(height: isExpanded ? (isHorizontal ? 204 : 124) : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)

        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .onChange(of: mode) { _, _ in
            withAnimation(expansionAnimation) { isExpanded = false }
        }
    }

    private var expansionAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.4)
    }

    private func modeOption(
        _ option: CameraControlEditorMode,
        title: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(expansionAnimation) {
                isExpanded = false
                action()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: mode == option ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(mode == option ? Color.yellow : Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, minHeight: isHorizontal ? 100 : 60)
            .cameraControlContentRotation()
            .contentShape(Rectangle())
            .background(.white.opacity(mode == option ? 0.12 : 0.04), in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(title)
        .accessibilityIdentifier("\(accessibilityLabel).\(title)")
        .accessibilityValue(mode == option ? "Selected" : "Not selected")
        .accessibilityAddTraits(mode == option ? .isSelected : [])
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
