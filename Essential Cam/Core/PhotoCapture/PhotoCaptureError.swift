//
//  PhotoCaptureError.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import Foundation

enum PhotoCaptureError: Error {
    case noPhotoData
    case photoProcessingFailed
    case photoLibraryUnauthorized
    case photoLibrarySaveFailed
}
