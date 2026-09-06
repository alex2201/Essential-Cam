//
//  AVCaptureDevice+DomainModel.swift
//  Essential Cam
//
//  Created by Alexander López on 06/09/26.
//

@preconcurrency import AVFoundation

extension AVCaptureDevice {
    func toDomainModel(displayZoomFactor: Double? = nil) -> Camera? {
        guard let position = domainPosition else {
            return nil
        }

        return Camera(
            id: uniqueID,
            name: localizedName,
            position: position,
            lens: domainLens,
            displayZoomFactor: displayZoomFactor
        )
    }

    private var domainPosition: Camera.Position? {
        switch position {
        case .front:
            return .front
        case .back:
            return .back
        case .unspecified:
            return nil
        @unknown default:
            return nil
        }
    }

    private var domainLens: Camera.Lens {
        switch deviceType {
        case .builtInUltraWideCamera:
            return .ultraWideAngle
        case .builtInWideAngleCamera:
            return .wideAngle
        case .builtInTelephotoCamera:
            return .telephoto
        default:
            return .unknown
        }
    }
}
