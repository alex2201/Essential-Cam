//
//  DefaultVideoCaptureService.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

import AVFoundation

final class DefaultVideoCaptureService: VideoCaptureService {
    var output: AVCaptureOutput {
        videoOutput
    }

    private let videoOutput = AVCaptureMovieFileOutput()

    func startRecording() {}

    func stopRecording() {}
}
