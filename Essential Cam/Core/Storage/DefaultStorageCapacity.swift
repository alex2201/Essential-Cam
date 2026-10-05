//
//  DefaultStorageCapacity.swift
//  Essential Cam
//
//  Created by Alexander López on 04/10/26.
//

import Foundation

// Filesystem queries run on this actor rather than the main actor.
actor DefaultStorageCapacity: StorageCapacityProviding {
    func availableCapacity() throws -> Int64? {
#if DEBUG
        // Deterministic UI validation without filling the device's storage.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-storageCapacityForTesting"),
           arguments.indices.contains(index + 1) {
            return Int64(arguments[index + 1])
        }
#endif
        let url = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values.volumeAvailableCapacityForImportantUsage
    }
}
