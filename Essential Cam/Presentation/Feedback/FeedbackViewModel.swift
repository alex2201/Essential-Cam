//
//  FeedbackViewModel.swift
//  Essential Cam
//
//  Created by Codex on 04/10/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class FeedbackViewModel {
    var message = ""
    private(set) var isSending = false
    var errorMessage: String?
    var showsSuccess = false

    private let repository: any FeedbackRepository
    private let appInfo: FeedbackAppInfo
    private var pending: FeedbackSubmission?

    init(repository: any FeedbackRepository = FirestoreFeedbackRepository(), appInfo: FeedbackAppInfo = FeedbackAppInfo()) {
        self.repository = repository
        self.appInfo = appInfo
    }

    var canSend: Bool {
        !isSending && !trimmedMessage.isEmpty
            && trimmedMessage.utf8.count <= SubmitFeedbackUseCase.maximumMessageBytes
    }

    var isMessageTooLong: Bool {
        trimmedMessage.utf8.count > SubmitFeedbackUseCase.maximumMessageBytes
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func send() async {
        guard canSend else { return }
        isSending = true
        errorMessage = nil
        showsSuccess = false
        defer { isSending = false }

        let feedback: FeedbackSubmission
        if let pending, pending.message == trimmedMessage {
            feedback = pending
        } else {
            feedback = FeedbackSubmission(
                id: UUID(), message: trimmedMessage,
                appVersion: appInfo.version, buildNumber: appInfo.buildNumber
            )
            pending = feedback
        }

        do {
            try await SubmitFeedbackUseCase(repository: repository).execute(feedback)
            message = ""
            pending = nil
            showsSuccess = true
        } catch is CancellationError {
            // Preserve the draft and document ID when the view's task is cancelled.
        } catch {
            if error as? FeedbackError == .accessDenied {
                errorMessage = "Feedback is unavailable right now. Your message has been kept. Please try again later."
            } else {
                errorMessage = "Couldn't send your feedback. Check your connection and try again. Your message has been kept."
            }
        }
    }
}
