//
//  FirestoreFeedbackRepository.swift
//  Essential Cam
//
//  Created by Codex on 04/10/26.
//

import FirebaseAuth
import FirebaseCore
import Foundation

@MainActor
struct FirestoreFeedbackRepository: FeedbackRepository {
    private let projectID: String?
    private let token: @MainActor () async throws -> String
    private let transport: @MainActor (URLRequest) async throws -> (Data, URLResponse)

    init(
        projectID: String? = nil,
        token: @escaping @MainActor () async throws -> String = {
            let auth = Auth.auth()
            let user: User
            if let current = auth.currentUser {
                user = current
            } else {
                user = try await auth.signInAnonymously().user
            }
            return try await user.getIDToken()
        },
        transport: @escaping @MainActor (URLRequest) async throws -> (Data, URLResponse) = {
            try await URLSession.shared.data(for: $0)
        }
    ) {
        self.projectID = projectID
        self.token = token
        self.transport = transport
    }

    func send(_ feedback: FeedbackSubmission) async throws {
        guard let project = projectID ?? FirebaseApp.app()?.options.projectID,
              !project.isEmpty else {
            throw FeedbackError.unavailable
        }
        let accessToken = try await token()
        try Task.checkCancellation()
        let database = "projects/\(project)/databases/(default)"
        let document = "\(database)/documents/feedbacks/\(feedback.id.uuidString)"
        guard let url = URL(string: "https://firestore.googleapis.com/v1/\(database)/documents:commit") else {
            throw FeedbackError.unavailable
        }

        // Use a bounded HTTP commit instead of an offline write queue. The immutable
        // document ID and create precondition make retries safe after a lost response.
        let body: [String: Any] = ["writes": [[
            "update": [
                "name": document,
                "fields": [
                    "message": ["stringValue": feedback.message],
                    "appVersion": ["stringValue": feedback.appVersion],
                    "buildNumber": ["stringValue": feedback.buildNumber]
                ]
            ],
            "updateTransforms": [["fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"]],
            "currentDocument": ["exists": false]
        ]]]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse else { throw FeedbackError.unavailable }
        if http.statusCode == 200 { return }
        // A retry must never overwrite an earlier accepted submission or its date.
        if http.statusCode == 409,
           let error = try? JSONDecoder().decode(ServerError.self, from: data),
           error.error.status == "ALREADY_EXISTS" {
            return
        }
        if http.statusCode == 401 || http.statusCode == 403 { throw FeedbackError.accessDenied }
        throw FeedbackError.unavailable
    }

    private struct ServerError: Decodable {
        let error: Status
        struct Status: Decodable { let status: String }
    }
}

struct FeedbackAppInfo {
    let version: String
    let buildNumber: String

    init(bundle: Bundle = .main) {
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    init(version: String, buildNumber: String) {
        self.version = version
        self.buildNumber = buildNumber
    }
}
