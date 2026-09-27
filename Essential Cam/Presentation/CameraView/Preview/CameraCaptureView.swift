//
//  CameraCaptureView.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

import SwiftUI

struct CameraCaptureView: View {
    let viewModel: CameraViewModel
    let showSettings: () -> Void

    @State private var isExposureDialPresented = false
    @State private var isFocusDialPresented = false
    @State private var isWhiteBalanceDialPresented = false
    @State private var isAspectRatioSelectorPresented = false
    @State private var isLensSelectorPresented = false
    @State private var isZoomSelectorPresented = false
    @State private var zoomFactorAtGestureStart: Double?

    var body: some View {
        GeometryReader { geometry in
            let previewContainerHeight = min(
                geometry.size.width * 16 / 9,
                geometry.size.height
            )
            let previewWidthToHeight = viewModel.controls.settings.aspectRatio.previewWidthToHeight
            let cameraImageHeight = min(
                geometry.size.width / previewWidthToHeight,
                previewContainerHeight
            )
            let cameraImageTopInset = (previewContainerHeight - cameraImageHeight) / 2

            VStack(spacing: .zero) {
                ZStack {
                    Color.clear

                    CameraPreview(session: viewModel.captureSession)
                        .aspectRatio(
                            viewModel.controls.settings.aspectRatio.previewWidthToHeight,
                            contentMode: .fit
                        )
                        .clipped()
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .center
                        )
                        .contentShape(Rectangle())
                        .gesture(zoomGesture)
                }
                .frame(width: geometry.size.width, height: previewContainerHeight)
                .overlay(alignment: .topTrailing) {
                    CameraFlashButton(controls: viewModel.controls)
                        .padding(.top, cameraImageTopInset + 8)
                        .padding(.trailing, 8)
                }
                .overlay(alignment: .bottomTrailing) {
                    CameraSettingsButton(action: showSettings)
                        .padding(.bottom, cameraImageTopInset + 8)
                        .padding(.trailing, 8)
                }
                .overlay(alignment: .trailing) {
                    ZStack(alignment: .trailing) {
                        if isAspectRatioSelectorPresented {
                            AspectRatioSelectionView(
                                selectedAspectRatio: viewModel.controls.settings.aspectRatio,
                                selectAspectRatio: selectAspectRatio,
                                dismiss: dismissAspectRatioSelector
                            )
                            .transition(controlTransition)
                        } else if isExposureDialPresented {
                            exposureEditor
                                .transition(controlTransition)
                        } else if isFocusDialPresented {
                            focusEditor
                                .transition(controlTransition)
                        } else if isWhiteBalanceDialPresented {
                            whiteBalanceEditor
                                .transition(controlTransition)
                        } else if isLensSelectorPresented {
                            LensSelectionView(
                                physicalCameras: viewModel.availableCameras,
                                virtualCamera: viewModel.preferredVirtualCamera,
                                selectedCamera: viewModel.selectedCamera,
                                selectCamera: selectCamera,
                                dismiss: dismissLensSelector
                            )
                            .transition(controlTransition)
                        } else if isZoomSelectorPresented {
                            ZoomSelectionView(
                                zoomFactors: zoomSelectionFactors,
                                selectedZoomFactor: viewModel.controls.settings.zoomFactor,
                                selectZoomFactor: selectZoomFactor,
                                dismiss: dismissZoomSelector
                            )
                            .transition(controlTransition)
                        } else {
                            VStack(spacing: 24) {
                                QuickAccessControlsView(
                                    controls: viewModel.controls,
                                    showAspectRatioSelector: showAspectRatioSelector,
                                    showExposureEditor: showExposureEditor,
                                    showFocusEditor: showFocusEditor,
                                    showWhiteBalanceEditor: showWhiteBalanceEditor
                                )

                                CameraSelectionControlsView(
                                    camera: viewModel.selectedCamera,
                                    zoomFactor: viewModel.controls.settings.zoomFactor,
                                    canSelectZoom: !zoomSelectionFactors.isEmpty,
                                    canSwitchPosition: viewModel.canSwitchCameraPosition,
                                    isSwitchingPosition: viewModel.isSwitchingCameraPosition,
                                    showLensSelector: showLensSelector,
                                    showZoomSelector: showZoomSelector,
                                    toggleCameraPosition: toggleCameraPosition
                                )
                            }
                            .transition(controlTransition)
                        }
                    }
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: isAspectRatioSelectorPresented
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: isExposureDialPresented
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: isFocusDialPresented
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: isWhiteBalanceDialPresented
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: isLensSelectorPresented
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: isZoomSelectorPresented
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

                editorSeparator

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
            .cameraControlBackground(cornerRadius: 16)
            .animation(.easeInOut(duration: 0.25), value: exposureMode)

            Button(action: dismissExposureEditor) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .cameraControlCircleBackground()
            .accessibilityLabel("Close exposure control")
        }
        .padding(.trailing, 8)
    }

    private var focusEditor: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                focusModeMenu

                if focusMode == .manual {
                    editorSeparator

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
            .frame(width: 50)
            .cameraControlBackground(cornerRadius: 16)
            .animation(.easeInOut(duration: 0.25), value: focusMode)

            Button(action: dismissFocusEditor) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .cameraControlCircleBackground()
            .accessibilityLabel("Close focus control")
        }
        .padding(.trailing, 8)
    }

    private var whiteBalanceEditor: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                whiteBalanceModeMenu

                if whiteBalanceMode == .manual {
                    editorSeparator

                    HStack(spacing: 8) {
                        CameraValueDial(
                            value: manualWhiteBalanceTemperature,
                            range: viewModel.controls.whiteBalanceTemperatureRange,
                            step: 100,
                            title: "TEMP",
                            orientation: .vertical,
                            valueFormatter: formatWhiteBalanceTemperature,
                            showsBackground: false
                        )
                        .frame(width: 50, height: 280)

                        CameraValueDial(
                            value: manualWhiteBalanceTint,
                            range: viewModel.controls.whiteBalanceTintRange,
                            step: 1,
                            title: "TINT",
                            orientation: .vertical,
                            neutralValue: 0,
                            valueFormatter: formatWhiteBalanceTint,
                            showsBackground: false
                        )
                        .frame(width: 50, height: 280)
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: whiteBalanceMode == .manual ? 108 : 50)
            .cameraControlBackground(cornerRadius: 16)
            .animation(.easeInOut(duration: 0.25), value: whiteBalanceMode)

            Button(action: dismissWhiteBalanceEditor) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .cameraControlCircleBackground()
            .accessibilityLabel("Close white balance control")
        }
        .padding(.trailing, 8)
    }

    private var focusModeMenu: some View {
        Menu {
            Button(action: viewModel.controls.useAutomaticFocus) {
                settingLabel("Automatic", isSelected: focusMode == .automatic)
            }
            .disabled(!viewModel.controls.supportsAutomaticFocus)

            Button(action: viewModel.controls.useManualFocus) {
                settingLabel("Manual", isSelected: focusMode == .manual)
            }
            .disabled(!viewModel.controls.supportsManualFocus)
        } label: {
            HStack(spacing: 2) {
                Text(focusMode.displayName)
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
        .accessibilityLabel("Focus mode")
    }

    private var exposureModeMenu: some View {
        Menu {
            Button(action: viewModel.controls.useAutomaticExposure) {
                settingLabel(
                    "Automatic",
                    isSelected: exposureMode == .automatic
                )
            }

            Button(action: viewModel.controls.useManualExposure) {
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

    private var whiteBalanceModeMenu: some View {
        Menu {
            Button(action: viewModel.controls.useAutomaticWhiteBalance) {
                settingLabel(
                    "Automatic",
                    isSelected: whiteBalanceMode == .automatic
                )
            }
            .disabled(!viewModel.controls.supportsAutomaticWhiteBalance)

            Button(action: viewModel.controls.useManualWhiteBalance) {
                settingLabel(
                    "Manual",
                    isSelected: whiteBalanceMode == .manual
                )
            }
            .disabled(!viewModel.controls.supportsManualWhiteBalance)
        } label: {
            HStack(spacing: 2) {
                Text(whiteBalanceMode.displayName)
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
        .accessibilityLabel("White balance mode")
    }

    private var automaticExposureDial: some View {
        CameraValueDial(
            value: exposureBias,
            range: viewModel.controls.exposureBiasRange,
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

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let startingZoomFactor = zoomFactorAtGestureStart
                    ?? viewModel.controls.settings.zoomFactor
                zoomFactorAtGestureStart = startingZoomFactor
                viewModel.controls.setZoomFactor(
                    startingZoomFactor * Double(value.magnification)
                )
            }
            .onEnded { _ in
                zoomFactorAtGestureStart = nil
            }
    }

    private var zoomSelectionFactors: [Double] {
        guard let selectedCamera = viewModel.selectedCamera else { return [] }

        let baseZoomFactor: Double
        switch selectedCamera.deviceKind {
        case .physical:
            baseZoomFactor = selectedCamera.displayZoomFactor
                ?? viewModel.controls.zoomFactorRange.lowerBound
        case .virtual:
            baseZoomFactor = 1
        }
        let supportedRange = viewModel.controls.zoomFactorRange

        return [1.0, 2.0, 4.0]
            .map { baseZoomFactor * $0 }
            .filter { supportedRange.contains($0) }
    }

    private var editorSeparator: some View {
        Rectangle()
            .fill(.white.opacity(0.7))
            .frame(height: 1)
            .padding(.horizontal, 8)
    }

    private var exposureBias: Binding<Double> {
        Binding(
            get: {
                Double(viewModel.controls.settings.exposure.exposureBias ?? 0)
            },
            set: { newValue in
                viewModel.controls.setExposureBias(Float(newValue))
            }
        )
    }

    private var manualISOStops: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(iso, _) = viewModel.controls.settings.exposure else {
                    return isoStopsRange.lowerBound
                }
                return log2(Double(iso))
            },
            set: { stops in
                viewModel.controls.setManualExposureISO(Float(pow(2, stops)))
            }
        )
    }

    private var manualDurationStops: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(_, duration) = viewModel.controls.settings.exposure else {
                    return durationStopsRange.lowerBound
                }
                return log2(duration)
            },
            set: { stops in
                viewModel.controls.setManualExposureDuration(pow(2, stops))
            }
        )
    }

    private var isoStopsRange: ClosedRange<Double> {
        let lowerBound = log2(viewModel.controls.exposureISORange.lowerBound)
        let upperBound = log2(viewModel.controls.exposureISORange.upperBound)
        return lowerBound...upperBound
    }

    private var durationStopsRange: ClosedRange<Double> {
        let lowerBound = log2(viewModel.controls.exposureDurationRange.lowerBound)
        let upperBound = log2(viewModel.controls.exposureDurationRange.upperBound)
        return lowerBound...upperBound
    }

    private var exposureMode: ExposureEditorMode {
        switch viewModel.controls.settings.exposure {
        case .automatic:
            .automatic
        case .manual:
            .manual
        }
    }

    private var manualFocusPosition: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(lensPosition) = viewModel.controls.settings.focus else {
                    return 0.5
                }
                return Double(lensPosition)
            },
            set: { viewModel.controls.setManualFocusLensPosition(Float($0)) }
        )
    }

    private var focusMode: FocusEditorMode {
        switch viewModel.controls.settings.focus {
        case .manual:
            .manual
        case .auto, .continuousAuto, .locked:
            .automatic
        }
    }

    private var manualWhiteBalanceTemperature: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(temperature, _) = viewModel.controls.settings.whiteBalance else {
                    return 5_500
                }
                return Double(temperature)
            },
            set: { viewModel.controls.setManualWhiteBalanceTemperature(Float($0)) }
        )
    }

    private var manualWhiteBalanceTint: Binding<Double> {
        Binding(
            get: {
                guard case let .manual(_, tint) = viewModel.controls.settings.whiteBalance else {
                    return 0
                }
                return Double(tint)
            },
            set: { viewModel.controls.setManualWhiteBalanceTint(Float($0)) }
        )
    }

    private var whiteBalanceMode: WhiteBalanceEditorMode {
        switch viewModel.controls.settings.whiteBalance {
        case .manual:
            .manual
        case .auto, .continuousAuto, .locked:
            .automatic
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

    private func formatFocusPosition(_ position: Double) -> String {
        switch position {
        case 0:
            "NEAR"
        case 1:
            "FAR"
        default:
            "\(Int((position * 100).rounded()))%"
        }
    }

    private func formatWhiteBalanceTemperature(_ temperature: Double) -> String {
        "\(Int(temperature.rounded()))K"
    }

    private func formatWhiteBalanceTint(_ tint: Double) -> String {
        let value = Int(tint.rounded())
        return value > 0 ? "+\(value)" : "\(value)"
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
            isAspectRatioSelectorPresented = false
            isFocusDialPresented = false
            isWhiteBalanceDialPresented = false
            isLensSelectorPresented = false
            isZoomSelectorPresented = false
            isExposureDialPresented = true
        }
    }

    private func dismissExposureEditor() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isExposureDialPresented = false
        }
    }

    private func showFocusEditor() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isAspectRatioSelectorPresented = false
            isExposureDialPresented = false
            isWhiteBalanceDialPresented = false
            isLensSelectorPresented = false
            isZoomSelectorPresented = false
            isFocusDialPresented = true
        }
    }

    private func dismissFocusEditor() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isFocusDialPresented = false
        }
    }


    private func showWhiteBalanceEditor() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isAspectRatioSelectorPresented = false
            isExposureDialPresented = false
            isFocusDialPresented = false
            isLensSelectorPresented = false
            isZoomSelectorPresented = false
            isWhiteBalanceDialPresented = true
        }
    }

    private func dismissWhiteBalanceEditor() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isWhiteBalanceDialPresented = false
        }
    }

    private func showLensSelector() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isAspectRatioSelectorPresented = false
            isExposureDialPresented = false
            isFocusDialPresented = false
            isWhiteBalanceDialPresented = false
            isZoomSelectorPresented = false
            isLensSelectorPresented = true
        }
    }

    private func dismissLensSelector() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isLensSelectorPresented = false
        }
    }

    private func showZoomSelector() {
        guard !zoomSelectionFactors.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            isAspectRatioSelectorPresented = false
            isExposureDialPresented = false
            isFocusDialPresented = false
            isWhiteBalanceDialPresented = false
            isLensSelectorPresented = false
            isZoomSelectorPresented = true
        }
    }

    private func dismissZoomSelector() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isZoomSelectorPresented = false
        }
    }

    private func showAspectRatioSelector() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isExposureDialPresented = false
            isFocusDialPresented = false
            isWhiteBalanceDialPresented = false
            isLensSelectorPresented = false
            isZoomSelectorPresented = false
            isAspectRatioSelectorPresented = true
        }
    }

    private func dismissAspectRatioSelector() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isAspectRatioSelectorPresented = false
        }
    }

    private func selectAspectRatio(_ aspectRatio: CameraAspectRatio) {
        viewModel.controls.setAspectRatio(aspectRatio)
        dismissAspectRatioSelector()
    }

    private func selectZoomFactor(_ zoomFactor: Double) {
        viewModel.controls.setZoomFactor(zoomFactor)
        dismissZoomSelector()
    }

    private func selectCamera(_ camera: Camera) {
        dismissAspectRatioSelector()
        dismissZoomSelector()
        viewModel.selectCamera(camera)
        dismissLensSelector()
    }

    private func toggleCameraPosition() {
        dismissAspectRatioSelector()
        dismissLensSelector()
        dismissZoomSelector()
        viewModel.toggleCameraPosition()
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

private enum FocusEditorMode: Equatable {
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

private enum WhiteBalanceEditorMode: Equatable {
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
