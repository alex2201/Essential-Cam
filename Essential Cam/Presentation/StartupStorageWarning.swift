//
//  StartupStorageWarning.swift
//  Essential Cam
//
//  Created by Alexander López on 04/10/26.
//

import Foundation

struct StartupStorageWarning: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init?(result: StorageCheckResult) {
        switch result {
        case .sufficient:
            return nil
        case .low(let bytes):
            title = "Low Storage"
            let available = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .decimal)
            message = "Only \(available) is available on this iPhone. Photos and videos may fail to save, and video recording may stop early. Free up space in Settings > General > iPhone Storage before capturing."
        case .unavailable:
            title = "Storage Check Unavailable"
            message = "Available storage could not be checked. If your iPhone is nearly full, photos and videos may fail to save. Check Settings > General > iPhone Storage before capturing."
        }
    }
}
