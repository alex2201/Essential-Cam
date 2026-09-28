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

enum CameraInterruption: Equatable, Sendable {
    case appInactive
    case audioOrVideoInUse
    case multipleForegroundApps
    case systemPressure
    case unknown
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
    case capturingPhoto
    case switchingCamera
    case reconfiguring
    case recovering
}

enum CameraSessionEvent: Sendable {
    case interrupted(CameraInterruption)
    case interruptionEnded
    case runtimeError(CameraRuntimeFailure)
}

enum CameraRuntimeFailure: Sendable {
    case mediaServicesWereReset
    case other
}
