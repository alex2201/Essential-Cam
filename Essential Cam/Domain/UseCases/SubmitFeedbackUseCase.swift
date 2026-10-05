//
//  SubmitFeedbackUseCase.swift
//  Essential Cam
//
//  Created by Alexander López on 04/10/26.
//

import Foundation

struct FeedbackSubmission: Equatable, Sendable {
    let id: UUID
    let message: String
    let appVersion: String
    let buildNumber: String
}

@MainActor
protocol FeedbackRepository {
    func send(_ feedback: FeedbackSubmission) async throws
}

enum FeedbackError: Error, Equatable {
    case emptyMessage
    case messageTooLong
    case unavailable
    case accessDenied
}

struct SubmitFeedbackUseCase {
    static let maximumMessageBytes = 5_000
    let repository: any FeedbackRepository

    @MainActor
    func execute(_ feedback: FeedbackSubmission) async throws {
        guard !feedback.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FeedbackError.emptyMessage
        }
        guard feedback.message.utf8.count <= Self.maximumMessageBytes else {
            throw FeedbackError.messageTooLong
        }
        guard !feedback.appVersion.isEmpty, !feedback.buildNumber.isEmpty else {
            throw FeedbackError.unavailable
        }
        try Task.checkCancellation()
        try await repository.send(feedback)
    }
}
