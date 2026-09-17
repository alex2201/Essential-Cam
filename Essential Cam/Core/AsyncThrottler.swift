//
//  AsyncThrottler.swift
//  Essential Cam
//

import Foundation

@MainActor
protocol Throttling<Value>: AnyObject {
    associatedtype Value: Sendable

    func submit(_ value: Value)
    func submitImmediately(_ value: Value)
    func cancel()
}

/// Executes the first value immediately and, while values keep arriving,
/// executes the latest value at most once per interval.
@MainActor
final class AsyncThrottler<Value: Sendable> {
    private let interval: Duration
    private let operation: @Sendable (Value) async -> Void
    private let clock = ContinuousClock()

    private var scheduledTask: Task<Void, Never>?
    private var operationTask: Task<Void, Never>?
    private var lastExecution: ContinuousClock.Instant?
    private var latestValue: Value?

    init(
        interval: Duration,
        operation: @escaping @Sendable (Value) async -> Void
    ) {
        self.interval = interval
        self.operation = operation
    }

    func submit(_ value: Value) {
        latestValue = value
        scheduledTask?.cancel()

        let now = clock.now
        guard let lastExecution else {
            executeLatestValue()
            return
        }

        let elapsed = lastExecution.duration(to: now)
        guard elapsed < interval else {
            executeLatestValue()
            return
        }

        let delay = interval - elapsed
        scheduledTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.executeLatestValue()
        }
    }

    func submitImmediately(_ value: Value) {
        scheduledTask?.cancel()
        latestValue = value
        executeLatestValue()
    }

    func cancel() {
        scheduledTask?.cancel()
        operationTask?.cancel()
        scheduledTask = nil
        operationTask = nil
        latestValue = nil
        lastExecution = nil
    }

    private func executeLatestValue() {
        guard let latestValue else { return }

        scheduledTask = nil
        self.latestValue = nil
        lastExecution = clock.now

        operationTask?.cancel()
        operationTask = Task { [operation] in
            guard !Task.isCancelled else { return }
            await operation(latestValue)
        }
    }
}

extension AsyncThrottler: Throttling {}
