//
//  FeedbackView.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import SwiftUI

struct FeedbackView: View {
    @State private var viewModel: FeedbackViewModel
    @State private var requestsSend = false
    @FocusState private var isEditing: Bool

    init() {
        #if DEBUG
        if let scenario = ProcessInfo.processInfo.environment["feedbackResponseForTesting"] {
            _viewModel = State(initialValue: FeedbackViewModel(repository: FeedbackTestingRepository(scenario: scenario)))
            return
        }
        #endif
        _viewModel = State(initialValue: FeedbackViewModel())
    }

    var body: some View {
        Form {
            Section {
                TextField("Share a comment or suggest a feature…", text: $viewModel.message, axis: .vertical)
                    .lineLimit(6...12)
                    .focused($isEditing)
                    .disabled(viewModel.isSending)
                    .accessibilityLabel("Feedback message")
                    .accessibilityIdentifier("feedback.message")
            } header: {
                Text("Your feedback")
            } footer: {
                Text("Tell us what you think or what you would like to see in Essential Cam.")
                if viewModel.isMessageTooLong {
                    Text("Your message is too long. Please shorten it before sending.")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    isEditing = false
                    requestsSend = true
                } label: {
                    HStack {
                        Text(viewModel.isSending ? "Sending…" : "Send")
                        if viewModel.isSending { ProgressView() }
                    }
                }
                    .disabled(!viewModel.canSend || requestsSend)
                    .accessibilityIdentifier("feedback.send")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isSending)
        .interactiveDismissDisabled(viewModel.isSending)
        .task(id: requestsSend) {
            guard requestsSend else { return }
            await viewModel.send()
            requestsSend = false
        }
        .alert("Feedback Sent", isPresented: $viewModel.showsSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thank you for helping improve Essential Cam.")
        }
        .alert("Couldn't Send Feedback", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Retry") { requestsSend = true }
            Button("Cancel", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#if DEBUG
@MainActor
private final class FeedbackTestingRepository: FeedbackRepository {
    private let scenario: String
    private var attempts = 0

    init(scenario: String) { self.scenario = scenario }

    func send(_ feedback: FeedbackSubmission) async throws {
        attempts += 1
        try await Task.sleep(for: .milliseconds(500))
        if scenario == "failure" || (scenario == "retry" && attempts == 1) {
            throw FeedbackError.unavailable
        }
    }
}
#endif

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
