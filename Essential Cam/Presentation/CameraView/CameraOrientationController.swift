//
//  CameraOrientationController.swift
//  Essential Cam
//
//  Created by Alexander López on 05/10/26.
//

import Observation
import UIKit

/// Retained by the camera screen for its observation lifecycle and last valid reading.
@MainActor
@Observable
final class CameraOrientationController {
    private(set) var orientation: CaptureOrientation?

    func observe() async {
        let device = UIDevice.current
        let center = NotificationCenter.default
        let stream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let observer = center.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: device,
            queue: nil
        ) { _ in
            stream.continuation.yield(())
        }
        device.beginGeneratingDeviceOrientationNotifications()
        defer {
            center.removeObserver(observer)
            stream.continuation.finish()
            device.endGeneratingDeviceOrientationNotifications()
        }

        update(device.orientation)
        for await _ in stream.stream {
            guard !Task.isCancelled else { return }
            update(device.orientation)
        }
    }

    func update(_ reading: UIDeviceOrientation) {
        switch reading {
        case .portrait: orientation = .portrait
        case .portraitUpsideDown: orientation = .portraitUpsideDown
        case .landscapeLeft: orientation = .landscapeLeft
        case .landscapeRight: orientation = .landscapeRight
        case .unknown, .faceUp, .faceDown: break
        @unknown default: break
        }
    }
}

extension CaptureOrientation {
    var detectionLabel: String {
        switch self {
        case .portrait: "Vertical"
        case .portraitUpsideDown: "Vertical · upside down"
        // UIDevice names landscape orientations by where the top of the device points.
        case .landscapeLeft: "Horizontal · top to left"
        case .landscapeRight: "Horizontal · top to right"
        }
    }
}
