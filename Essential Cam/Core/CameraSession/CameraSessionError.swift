//
//  CameraSessionError.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

enum CameraSessionError: Error {
    case unauthorized
    case setupFailed
    case cameraNotFound
    case addInputFailed
    case addOutputFailed
    case configurationFailed
    case operationInProgress
}
