//
//  PhotoCapturing.swift
//  Essential Cam
//
//  Created by Alexander López on 04/09/26.
//

protocol PhotoCapturing: Sendable {
    func capturePhoto() async throws -> Photo
}
