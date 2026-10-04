//
//  StorageCapacityTests.swift
//  Essential CamTests
//
//  Created by Codex on 04/10/26.
//

import Testing
@testable import Essential_Cam

struct StorageCapacityTests {
    @Test(arguments: [Int64(0), 1, 999_999_999])
    func lowStorageIncludesRemainingBytes(_ bytes: Int64) async {
        let result = await CheckStorageUseCase(storage: StubStorage(bytes: bytes)).execute()
        #expect(result == .low(availableBytes: bytes))
    }

    @Test(arguments: [Int64(1_000_000_000), 10_000_000_000])
    func thresholdAndHigherDoNotWarn(_ bytes: Int64) async {
        let result = await CheckStorageUseCase(storage: StubStorage(bytes: bytes)).execute()
        #expect(result == .sufficient)
        #expect(StartupStorageWarning(result: result) == nil)
    }

    @Test(arguments: [nil, Int64(-1)])
    func missingOrInvalidCapacityIsNotTreatedAsSufficient(_ bytes: Int64?) async {
        let result = await CheckStorageUseCase(storage: StubStorage(bytes: bytes)).execute()
        #expect(result == .unavailable)
        #expect(StartupStorageWarning(result: result)?.title == "Storage Check Unavailable")
    }

    @Test func readFailureProducesRecoverableWarning() async {
        let result = await CheckStorageUseCase(storage: FailingStorage()).execute()
        #expect(result == .unavailable)
    }

    @Test func lowStorageMessageCoversBothCaptureModes() {
        let warning = StartupStorageWarning(result: .low(availableBytes: 500_000_000))
        #expect(warning?.title == "Low Storage")
        #expect(warning?.message.contains("500 MB") == true)
        #expect(warning?.message.contains("Photos and videos") == true)
    }
}

private struct StubStorage: StorageCapacityProviding {
    let bytes: Int64?
    func availableCapacity() async throws -> Int64? { bytes }
}

private struct FailingStorage: StorageCapacityProviding {
    enum Failure: Error { case unavailable }
    func availableCapacity() async throws -> Int64? { throw Failure.unavailable }
}
