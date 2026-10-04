//
//  VideoCaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

import Foundation

protocol VideoCaptureService: CameraCaptureComponent {
    func record(to url: URL, didStart: @escaping @Sendable () -> Void) async throws
    func stopRecording()
}
