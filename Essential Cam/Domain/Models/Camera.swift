//
//  Camera.swift
//  Essential Cam
//
//  Created by Alexander López on 06/09/26.
//

struct Camera: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let position: Position
    let lens: Lens
    /// Lens magnification relative to the main camera, independent of current zoom.
    let displayZoomFactor: Double?
}

extension Camera {
    enum Position: Sendable, Equatable {
        case front
        case back
    }

    enum Lens: Sendable, Equatable {
        case ultraWideAngle
        case wideAngle
        case telephoto
        case unknown
    }
}
