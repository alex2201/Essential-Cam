//
//  CameraSessionEvent.swift
//  Essential Cam
//
//  Created by Codex on 04/10/26.
//

import Foundation

struct CameraSessionSnapshot: Sendable {
    let isConfigured: Bool
    let isRunning: Bool
    let isInterrupted: Bool
    let selectedCamera: Camera?

    var isAvailable: Bool { isRunning && !isInterrupted }
}

enum CameraInterruption: Equatable, Sendable {
    case appInactive
    case audioOrVideoInUse
    case multipleForegroundApps
    case systemPressure
    case unknown
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
