//
//  CameraStatus.swift
//  Essential Cam
//
//  Created by Alexander López on 02/09/26.
//

import Foundation

/// An enumeration that describes the current status of the camera.
enum CameraStatus: Equatable {
    case idle
    case requestingPermission
    case starting
    case running
    case interrupted(CameraInterruption)
    case recovering
    case unauthorized
    case failed(CameraFailure)
}

enum CameraFailure: Equatable, Sendable {
    case configuration
    case cameraUnavailable
    case mediaServicesReset
    case capture
    case photoLibrary
    case insufficientStorage
    case unknown
}

enum CameraOperation: Equatable {
    case none
    case starting
    case capturingPhoto
    case switchingCamera
    case recovering
}
