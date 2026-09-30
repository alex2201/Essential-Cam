@preconcurrency import AVFoundation
import Foundation

/// Bridges AVFoundation notifications into a Sendable event stream. The
/// capture-session actor remains the only owner allowed to mutate the session.
final class CameraSessionEventMonitor: @unchecked Sendable {
    let events: AsyncStream<CameraSessionEvent>

    private let center: NotificationCenter
    private var observers: [NSObjectProtocol] = []
    private let continuation: AsyncStream<CameraSessionEvent>.Continuation

    init(
        session: AVCaptureSession,
        center: NotificationCenter = .default
    ) {
        self.center = center
        let stream = AsyncStream<CameraSessionEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(10)
        )
        events = stream.stream
        continuation = stream.continuation

        observers.append(
            center.addObserver(
                forName: AVCaptureSession.wasInterruptedNotification,
                object: session,
                queue: nil
            ) { [continuation] notification in
                continuation.yield(
                    .interrupted(Self.interruption(from: notification))
                )
            }
        )
        observers.append(
            center.addObserver(
                forName: AVCaptureSession.interruptionEndedNotification,
                object: session,
                queue: nil
            ) { [continuation] _ in
                continuation.yield(.interruptionEnded)
            }
        )
        observers.append(
            center.addObserver(
                forName: AVCaptureSession.runtimeErrorNotification,
                object: session,
                queue: nil
            ) { [continuation] notification in
                continuation.yield(
                    .runtimeError(Self.runtimeFailure(from: notification))
                )
            }
        )
    }

    deinit {
        observers.forEach(center.removeObserver)
        continuation.finish()
    }

    private static func interruption(from notification: Notification) -> CameraInterruption {
        guard
            let rawValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey]
                as? NSNumber,
            let reason = AVCaptureSession.InterruptionReason(rawValue: rawValue.intValue)
        else {
            return .unknown
        }

        switch reason {
        case .audioDeviceInUseByAnotherClient, .videoDeviceInUseByAnotherClient:
            return .audioOrVideoInUse
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            return .multipleForegroundApps
        case .videoDeviceNotAvailableDueToSystemPressure:
            return .systemPressure
        case .videoDeviceNotAvailableInBackground:
            return .appInactive
        case .sensitiveContentMitigationActivated:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    private static func runtimeFailure(from notification: Notification) -> CameraRuntimeFailure {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return .other
        }

        return error.domain == AVFoundationErrorDomain
            && error.code == AVError.Code.mediaServicesWereReset.rawValue
            ? .mediaServicesWereReset
            : .other
    }
}
