//
//  Photo.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import CoreGraphics
import Foundation

struct Photo: Sendable {
    let data: Data
    let previewImage: CGImage?
}
