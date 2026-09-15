//
//  CameraCaptureView.swift
//  Essential Cam
//

import SwiftUI

struct CameraCaptureView: View {
    let viewModel: CameraViewModel

    @State private var isExposureDialPresented = false

    var body: some View {
        GeometryReader { geometry in
            let previewContainerHeight = min(
                geometry.size.width * 16 / 9,
                geometry.size.height
            )

            VStack(spacing: .zero) {
                ZStack {
                    Color.clear

                    CameraPreview(session: viewModel.captureSession)
                        .aspectRatio(
                            viewModel.cameraSettings.aspectRatio.previewWidthToHeight,
                            contentMode: .fit
                        )
                        .clipped()
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .center
                        )
                }
                .frame(width: geometry.size.width, height: previewContainerHeight)
                .overlay(alignment: .trailing) {
                    ZStack(alignment: .trailing) {
                        if isExposureDialPresented {
                            exposureEditor
                                .transition(controlTransition)
                        } else {
                            QuickAccessControlsView(
                                viewModel: viewModel,
                                showExposureEditor: showExposureEditor
                            )
                            .transition(controlTransition)
                        }
                    }
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: isExposureDialPresented
                    )
                }

                CaptureControlsView(
                    captureAction: viewModel.captureAction,
                    isCaptureDisabled: viewModel.isPerformingCaptureOperation
                )
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height - previewContainerHeight
                )
            }
        }
    }

    private var exposureEditor: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                exposureModeMenu

                Group {
                    switch exposureMode {
                    case .automatic:
                        automaticExposureDial
                    case .manual:
                        manualExposureDials
                    }
                }
                .transition(.opacity)
            }
            .frame(width: exposureMode == .manual ? 108 : 50)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.55))
            }
            .animation(.easeInOut(duration: 0.25), value: exposureMode)

            Button(action: dismissExposureEditor) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background {
                        Circle()
                            .fill(.black.opacity(0.55))
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close exposure control")
        }
        .padding(.trailing, 8)
    }

    private var exposureModeMenu: some View {
        Menu {
            Button(action: viewModel.useAutomaticExposure) {
                settingLabel(
                    "Automatic",
                    isSelected: exposureMode == .automatic
                )
            }

            Button(action: viewModel.useManualExposure) {
                settingLabel(
                    "Manual",
                    isSelected: exposureMode == .manual
                )
            }
        } label: {
            HStack(spacing: 2) {
                Text(exposureMode.displayName)
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
        .accessibilityLabel("Exposure mode")
    }

    private var automaticExposureDial: some View {
        CameraValueDial(
            value: exposureBias,
            range: viewModel.exposureBiasRange,
            step: 0.1,
            title: "EV",
            orientation: .vertical,
            neutralValue: 0,
            showsBackground: false
        )
        .frame(width: 50, height: 280)
    }

    private var manualExposureDials: some View {
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

    private var controlTransition: AnyTransition {
        .move(edge: .trailing).combined(with: .opacity)
    }

    private var exposureBias: Binding<Double> {
        Binding(
            get: {
                Double(viewModel.cameraSettings.exposure.exposureBias ?? 0)
            },
            set: { newValue in
                viewModel.setExposureBias(Float(newValue))
            }
        )
    }

    private var manualISOStops: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(iso, _) = viewModel.cameraSettings.exposure else {
                    return isoStopsRange.lowerBound
                }
                return log2(Double(iso))
            },
            set: { stops in
                viewModel.setManualExposureISO(Float(pow(2, stops)))
            }
        )
    }

    private var manualDurationStops: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(_, duration) = viewModel.cameraSettings.exposure else {
                    return durationStopsRange.lowerBound
                }
                return log2(duration)
            },
            set: { stops in
                viewModel.setManualExposureDuration(pow(2, stops))
            }
        )
    }

    private var isoStopsRange: ClosedRange<Double> {
        let lowerBound = log2(viewModel.exposureISORange.lowerBound)
        let upperBound = log2(viewModel.exposureISORange.upperBound)
        return lowerBound...upperBound
    }

    private var durationStopsRange: ClosedRange<Double> {
        let lowerBound = log2(viewModel.exposureDurationRange.lowerBound)
        let upperBound = log2(viewModel.exposureDurationRange.upperBound)
        return lowerBound...upperBound
    }

    private var exposureMode: ExposureEditorMode {
        switch viewModel.cameraSettings.exposure {
        case .automatic:
            .automatic
        case .manual:
            .manual
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

    private func settingLabel(_ title: String, isSelected: Bool) -> some View {
        Group {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private func showExposureEditor() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isExposureDialPresented = true
        }
    }

    private func dismissExposureEditor() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isExposureDialPresented = false
        }
    }
}

private enum ExposureEditorMode: Equatable {
    case automatic
    case manual

    var displayName: String {
        switch self {
        case .automatic:
            "AUTO"
        case .manual:
            "MAN"
        }
    }
}
