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
            deviceKind: domainDeviceKind,
            displayZoomFactor: displayZoomFactor,
            nominalFocalLengthIn35mmFilm: domainNominalFocalLength
        )
    }

    private var domainNominalFocalLength: Double? {
        guard !isVirtualDevice else { return nil }

        if #available(iOS 26.0, *) {
            let focalLength = Double(nominalFocalLengthIn35mmFilm)
            return focalLength > 0 ? focalLength : nil
        }

        return nil
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

    private var domainDeviceKind: Camera.DeviceKind {
        guard isVirtualDevice else { return .physical }

        let type: Camera.VirtualDeviceType
        switch deviceType {
        case .builtInDualCamera:
            type = .dual
        case .builtInDualWideCamera:
            type = .dualWide
        case .builtInTripleCamera:
            type = .triple
        default:
            type = .unknown
        }
        return .virtual(type)
    }
}
