//
//  FeedbackTests.swift
//  Essential CamTests
//
//  Created by Codex on 04/10/26.
//

import Foundation
import Testing
@testable import Essential_Cam

@MainActor
struct FeedbackTests {
    private let info = FeedbackAppInfo(version: "2.1", buildNumber: "42")

    @Test func blankAndOversizedMessagesNeverReachTheRepository() async {
        let repository = RecordingFeedbackRepository()
        let model = FeedbackViewModel(repository: repository, appInfo: info)
        for message in ["", " \n\t", String(repeating: "a", count: 5001), String(repeating: "📷", count: 1251)] {
            model.message = message
            #expect(!model.canSend)
            await model.send()
        }
        #expect(repository.submissions.isEmpty)
    }

    @Test func successfulSubmissionUsesInstalledMetadataAndClearsDraft() async {
        let repository = RecordingFeedbackRepository()
        let model = FeedbackViewModel(repository: repository, appInfo: info)
        model.message = " \nAdd presets, please.\n "
        await model.send()
        #expect(repository.submissions.count == 1)
        #expect(repository.submissions.first?.message == "Add presets, please.")
        #expect(repository.submissions.first?.appVersion == "2.1")
        #expect(repository.submissions.first?.buildNumber == "42")
        #expect(model.message.isEmpty)
        #expect(model.showsSuccess)
        #expect(!model.isSending)
    }

    @Test func failureRetainsDraftAndRetryUsesSameDocument() async {
        let repository = RecordingFeedbackRepository()
        repository.failuresRemaining = 1
        let model = FeedbackViewModel(repository: repository, appInfo: info)
        model.message = "Please add a feature."
        await model.send()
        #expect(model.message == "Please add a feature.")
        #expect(model.errorMessage != nil)
        #expect(!model.showsSuccess)
        #expect(model.canSend)
        await model.send()
        #expect(repository.submissions.count == 2)
        #expect(repository.submissions[0] == repository.submissions[1])
        #expect(model.errorMessage == nil)
        #expect(model.showsSuccess)
    }

    @Test func editedDraftAfterFailureGetsANewDocumentID() async {
        let repository = RecordingFeedbackRepository()
        repository.failuresRemaining = 1
        let model = FeedbackViewModel(repository: repository, appInfo: info)
        model.message = "Original"
        await model.send()
        model.message = "Changed"
        await model.send()
        #expect(repository.submissions[0].id != repository.submissions[1].id)
    }

    @Test func repeatedSendWhileWaitingDoesNotCreateTwoRequests() async {
        let repository = RecordingFeedbackRepository()
        repository.shouldWait = true
        let model = FeedbackViewModel(repository: repository, appInfo: info)
        model.message = "Camera feedback"
        let first = Task { await model.send() }
        while repository.submissions.isEmpty { await Task.yield() }
        #expect(model.isSending)
        #expect(!model.canSend)
        await model.send()
        repository.finish()
        await first.value
        #expect(repository.submissions.count == 1)
        #expect(!model.isSending)
    }

    @Test func cancellationPreservesDraftAndUnlocksControls() async {
        let repository = RecordingFeedbackRepository()
        repository.isCancelled = true
        let model = FeedbackViewModel(repository: repository, appInfo: info)
        model.message = "Keep this message"
        await model.send()
        #expect(model.message == "Keep this message")
        #expect(!model.isSending)
        #expect(!model.showsSuccess)
        #expect(model.errorMessage == nil)
    }

    @Test func missingAppMetadataDoesNotSubmit() async {
        let repository = RecordingFeedbackRepository()
        let model = FeedbackViewModel(repository: repository, appInfo: .init(version: "", buildNumber: "42"))
        model.message = "Feedback"
        await model.send()
        #expect(repository.submissions.isEmpty)
        #expect(model.message == "Feedback")
        #expect(model.errorMessage != nil)
    }

    @Test(arguments: ["dev-project", "prod-project"])
    func firestoreCommitContainsOnlyAgreedFieldsInSelectedProject(_ project: String) async throws {
        let submission = FeedbackSubmission(id: UUID(), message: "Feedback", appVersion: "2.1", buildNumber: "42")
        let repository = FirestoreFeedbackRepository(projectID: project, token: { "test-token" }, transport: { request in
            #expect(request.url?.path == "/v1/projects/\(project)/databases/(default)/documents:commit")
            #expect(request.httpMethod == "POST")
            #expect(request.timeoutInterval == 30)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            let requestData = try #require(request.httpBody)
            let decodedBody = try JSONSerialization.jsonObject(with: requestData)
            let body = try #require(decodedBody as? [String: Any])
            let writes = try #require(body["writes"] as? [[String: Any]])
            #expect(writes.count == 1)
            let update = try #require(writes[0]["update"] as? [String: Any])
            #expect(update["name"] as? String == "projects/\(project)/databases/(default)/documents/feedbacks/\(submission.id.uuidString)")
            let fields = try #require(update["fields"] as? [String: [String: String]])
            #expect(Set(fields.keys) == Set(["message", "appVersion", "buildNumber"]))
            #expect(fields["message"]?["stringValue"] == submission.message)
            #expect(fields["appVersion"]?["stringValue"] == "2.1")
            #expect(fields["buildNumber"]?["stringValue"] == "42")
            let transforms = try #require(writes[0]["updateTransforms"] as? [[String: String]])
            #expect(transforms == [["fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"]])
            #expect((writes[0]["currentDocument"] as? [String: Bool])?["exists"] == false)
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        try await repository.send(submission)
    }

    @Test(arguments: [401, 403, 409, 500])
    func rejectedWritesAreNotReportedAsSuccessful(_ status: Int) async {
        let repository = FirestoreFeedbackRepository(projectID: "dev-project", token: { "test-token" }, transport: { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        })
        let feedback = FeedbackSubmission(id: UUID(), message: "Feedback", appVersion: "1", buildNumber: "1")
        await #expect(throws: status == 401 || status == 403 ? FeedbackError.accessDenied : FeedbackError.unavailable) {
            try await repository.send(feedback)
        }
    }

    @Test func retryOfAcceptedDocumentSucceedsWithoutOverwritingIt() async throws {
        let repository = FirestoreFeedbackRepository(projectID: "dev-project", token: { "test-token" }, transport: { request in
            (Data(#"{"error":{"status":"ALREADY_EXISTS"}}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 409, httpVersion: nil, headerFields: nil)!)
        })
        try await repository.send(.init(id: UUID(), message: "Feedback", appVersion: "1", buildNumber: "1"))
    }

    @Test func authenticationFailureNeverAttemptsFirestoreWrite() async {
        let repository = FirestoreFeedbackRepository(projectID: "dev-project", token: { throw FeedbackError.accessDenied }, transport: { _ in
            Issue.record("Firestore must not be called without authentication")
            throw FeedbackError.unavailable
        })
        await #expect(throws: FeedbackError.accessDenied) {
            try await repository.send(.init(id: UUID(), message: "Feedback", appVersion: "1", buildNumber: "1"))
        }
    }

    @Test func networkFailureRetainsDraftForRetry() async {
        let repository = FirestoreFeedbackRepository(projectID: "dev-project", token: { "test-token" }, transport: { _ in
            throw URLError(.timedOut)
        })
        let model = FeedbackViewModel(repository: repository, appInfo: info)
        model.message = "Feedback"
        await model.send()
        #expect(model.message == "Feedback")
        #expect(model.errorMessage != nil)
        #expect(model.canSend)
    }
}

@MainActor
private final class RecordingFeedbackRepository: FeedbackRepository {
    var submissions: [FeedbackSubmission] = []
    var failuresRemaining = 0
    var isCancelled = false
    var shouldWait = false
    private var completion: CheckedContinuation<Void, Never>?

    func send(_ feedback: FeedbackSubmission) async throws {
        submissions.append(feedback)
        if shouldWait { await withCheckedContinuation { completion = $0 } }
        if isCancelled { throw CancellationError() }
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw FeedbackError.unavailable
        }
    }

    func finish() {
        completion?.resume()
        completion = nil
    }
}
