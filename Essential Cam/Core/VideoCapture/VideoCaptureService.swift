//
//  VideoCaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

protocol VideoCaptureService: CameraCaptureComponent {
    func startRecording()
    func stopRecording()
}
