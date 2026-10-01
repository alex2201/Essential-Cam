#if DEBUG
import Foundation

extension CameraPreset {
    static let debugSamples: [CameraPreset] = [
        CameraPreset(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Everyday",
            settings: CameraPresetSettings(
                exposure: .automatic(exposureBias: 0),
                focus: .continuousAuto,
                whiteBalance: .continuousAuto,
                aspectRatio: .fourByThree,
                flashMode: .off
            )
        ),
        CameraPreset(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "Golden Hour",
            settings: CameraPresetSettings(
                exposure: .manual(iso: 100, durationInSeconds: 1.0 / 250.0),
                focus: .manual(lensPosition: 0.65),
                whiteBalance: .manual(temperature: 6_500, tint: 8),
                aspectRatio: .sixteenByNine,
                flashMode: .off
            )
        ),
        CameraPreset(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            name: "Low Light",
            settings: CameraPresetSettings(
                exposure: .manual(iso: 800, durationInSeconds: 1.0 / 30.0),
                focus: nil,
                whiteBalance: .manual(temperature: 3_800, tint: -10),
                aspectRatio: .fourByThree,
                flashMode: .off
            )
        ),
        CameraPreset(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
            name: "Quick Snapshot",
            settings: CameraPresetSettings(
                exposure: .automatic(exposureBias: -0.3),
                focus: .auto,
                whiteBalance: .auto,
                aspectRatio: .square,
                flashMode: .automatic
            )
        )
    ]
}
#endif
