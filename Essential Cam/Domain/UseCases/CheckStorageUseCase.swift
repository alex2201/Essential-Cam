//
//  CheckStorageUseCase.swift
//  Essential Cam
//
//  Created by Alexander López on 04/10/26.
//

protocol StorageCapacityProviding: Sendable {
    func availableCapacity() async throws -> Int64?
}

enum StorageCheckResult: Equatable, Sendable {
    case sufficient
    case low(availableBytes: Int64)
    case unavailable
}

struct CheckStorageUseCase: Sendable {
    // A warning threshold, not a guarantee that any particular recording fits.
    static let lowStorageThreshold: Int64 = 1_000_000_000
    let storage: any StorageCapacityProviding

    func execute() async -> StorageCheckResult {
        do {
            guard let bytes = try await storage.availableCapacity(), bytes >= 0 else {
                return .unavailable
            }
            return bytes < Self.lowStorageThreshold ? .low(availableBytes: bytes) : .sufficient
        } catch {
            return .unavailable
        }
    }
}
