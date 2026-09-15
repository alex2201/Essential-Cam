//
//  CameraViewModel.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

@preconcurrency import AVFoundation
import Foundation

@MainActor
@Observable
class CameraViewModel {

    var cameraStatus = CameraStatus.unknown
    var isPerformingCaptureOperation = false
    var capturedPhotoPreview: CGImage?
    var isPhotoPreviewPresented = false
    var cameraSettings = CameraSettings.standard {
        didSet {
            guard cameraSettings != oldValue else { return }
            applyCameraSettings()
        }
    }
    private(set) var captureOrientation = CaptureOrientation.portrait
    private(set) var availableCameras: [Camera] = []
    private(set) var exposureBiasRange: ClosedRange<Double> = 0...0
    private(set) var exposureISORange: ClosedRange<Double> = 1...1
    private(set) var exposureDurationRange: ClosedRange<Double> = 1...1

    var captureSession: AVCaptureSession {
        cameraSession.captureSession
    }

    private let cameraSession: CameraSession
    private let settingsClock = ContinuousClock()
    private let settingsApplicationInterval: Duration = .milliseconds(100)
    private var settingsApplicationTask: Task<Void, Never>?
    private var lastSettingsApplication: ContinuousClock.Instant?
    private var automaticExposureBias: Float = 0
    private var manualExposureISO: Float = 1
    private var manualExposureDurationInSeconds: Double = 1

    init(
        cameraSession: CameraSession = .init()
    ) {
        self.cameraSession = cameraSession
    }

    func start() async {
        do {
            try await cameraSession.start()
            availableCameras = await cameraSession.availableCameras()
            await updateExposureCapabilities()
            cameraStatus = .running
            applyCameraSettingsImmediately()
        } catch {
            switch error {
            case .unauthorized:
                cameraStatus = .unauthorized
            case .setupFailed, .cameraNotFound, .addInputFailed,
                    .addOutputFailed, .configurationFailed:
                cameraStatus = .failed
            }
            print("Couldn't start capture: \(error.localizedDescription)")
        }
    }

    func captureAction() {
        guard !isPerformingCaptureOperation else { return }
        isPerformingCaptureOperation = true

        Task {
            defer { isPerformingCaptureOperation = false }

            let useCase = PhotoCaptureUseCase(
                photoCapture: cameraSession,
                photoSaving: DefaultPhotoLibrary()
            )

            do {
                let photo = try await useCase.execute()
                capturedPhotoPreview = photo.previewImage
                isPhotoPreviewPresented = photo.previewImage != nil
            } catch {
                print("Couldn't capture photo: \(error.localizedDescription)")
            }
        }
    }

    func selectCamera(_ camera: Camera) {
        Task {
            do {
                try await cameraSession.selectCamera(id: camera.id)
                await updateExposureCapabilities()
                try await cameraSession.apply(cameraSettings)
            } catch {
                print("Couldn't select camera: \(error.localizedDescription)")
            }
        }
    }

    func useAutomaticExposure() {
        cameraSettings.exposure = .automatic(
            exposureBias: automaticExposureBias
        )
    }

    func useManualExposure() {
        cameraSettings.exposure = .manual(
            iso: manualExposureISO,
            durationInSeconds: manualExposureDurationInSeconds
        )
    }

    func setExposureBias(_ exposureBias: Float) {
        automaticExposureBias = exposureBias
        cameraSettings.exposure = .automatic(exposureBias: exposureBias)
    }

    func setManualExposureISO(_ iso: Float) {
        manualExposureISO = iso
        cameraSettings.exposure = .manual(
            iso: iso,
            durationInSeconds: manualExposureDurationInSeconds
        )
    }

    func setManualExposureDuration(_ durationInSeconds: Double) {
        manualExposureDurationInSeconds = durationInSeconds
        cameraSettings.exposure = .manual(
            iso: manualExposureISO,
            durationInSeconds: durationInSeconds
        )
    }

    private func applyCameraSettings() {
        settingsApplicationTask?.cancel()

        let now = settingsClock.now

        guard let lastSettingsApplication else {
            applyCameraSettingsImmediately()
            return
        }

        let elapsed = lastSettingsApplication.duration(to: now)

        guard elapsed < settingsApplicationInterval else {
            applyCameraSettingsImmediately()
            return
        }

        let delay = settingsApplicationInterval - elapsed
        settingsApplicationTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.applyCameraSettingsImmediately()
        }
    }

    private func applyCameraSettingsImmediately() {
        settingsApplicationTask = nil
        lastSettingsApplication = settingsClock.now

        let settings = cameraSettings

        Task {
            do {
                try await cameraSession.apply(settings)
            } catch {
                print("Couldn't apply camera settings: \(error.localizedDescription)")
            }
        }
    }

    private func updateExposureCapabilities() async {
        guard let capabilities = await cameraSession.exposureCapabilities() else {
            return
        }

        exposureBiasRange = Double(capabilities.exposureBiasRange.lowerBound)...Double(capabilities.exposureBiasRange.upperBound)
        exposureISORange = Double(capabilities.isoRange.lowerBound)...Double(capabilities.isoRange.upperBound)
        exposureDurationRange = capabilities.durationRange

        manualExposureISO = capabilities.currentISO
        manualExposureDurationInSeconds = capabilities.currentDurationInSeconds

        switch cameraSettings.exposure {
        case let .automatic(exposureBias):
            let supportedBias = min(
                max(exposureBias, capabilities.exposureBiasRange.lowerBound),
                capabilities.exposureBiasRange.upperBound
            )
            automaticExposureBias = supportedBias

            if supportedBias != exposureBias {
                cameraSettings.exposure = .automatic(exposureBias: supportedBias)
            }
        case let .manual(iso, durationInSeconds):
            let supportedISO = min(
                max(iso, capabilities.isoRange.lowerBound),
                capabilities.isoRange.upperBound
            )
            let supportedDuration = min(
                max(durationInSeconds, capabilities.durationRange.lowerBound),
                capabilities.durationRange.upperBound
            )
            manualExposureISO = supportedISO
            manualExposureDurationInSeconds = supportedDuration

            if supportedISO != iso || supportedDuration != durationInSeconds {
                cameraSettings.exposure = .manual(
                    iso: supportedISO,
                    durationInSeconds: supportedDuration
                )
            }
        }
    }
}
