//
//  CameraDeviceLookup.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//


import AVFoundation

protocol CameraDeviceLookup {
    var backCameras: [AVCaptureDevice] { get }
    var frontCameras: [AVCaptureDevice] { get }
    var availableCameras: [AVCaptureDevice] { get }
    var mainBackCamera: AVCaptureDevice? { get }
    var mainFrontCamera: AVCaptureDevice? { get }
    func displayZoomFactor(for device: AVCaptureDevice) -> Double?
}
