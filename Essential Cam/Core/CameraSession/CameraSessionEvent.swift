import Foundation

struct CameraSessionSnapshot: Sendable {
    let isConfigured: Bool
    let isRunning: Bool
    let selectedCamera: Camera?
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
