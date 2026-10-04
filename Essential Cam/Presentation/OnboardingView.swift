import SwiftUI
import UIKit

struct OnboardingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var viewModel = OnboardingViewModel()
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("ESSENTIAL CAM")
                    .font(.caption.weight(.semibold))
                    .tracking(3)
                    .foregroundStyle(.secondary)

                Image(systemName: symbol)
                    .font(.system(size: 56, weight: .light))
                    .accessibilityHidden(true)
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("onboarding.title")
                    Text(message)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if viewModel.permission != nil {
                    Text("Permission \(viewModel.step) of \(viewModel.permissionCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if viewModel.status == .authorized {
                        Label("Access allowed", systemImage: "checkmark.circle")
                    } else if viewModel.status == .denied {
                        Text("Access is unavailable. You can review permissions in Settings or continue with the available features.")
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                }

                Button {
                    Task { await viewModel.performPrimaryAction() }
                } label: {
                    HStack {
                        Text(buttonTitle)
                        Spacer()
                        if viewModel.isRequesting {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .padding(8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .disabled(viewModel.isPrimaryActionDisabled)
                .accessibilityIdentifier("onboarding.continue")

                Text("You stay in control. Change access at any time in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task(id: viewModel.step) { await viewModel.refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.refreshStatus() }
            }
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete { onComplete() }
        }
        .onDisappear { viewModel.cancelPendingOperations() }
    }

    private var buttonTitle: String {
        if viewModel.permission == nil { return "Get Started" }
        if viewModel.isRequesting { return "Requesting Access…" }
        if viewModel.status == .notDetermined { return "Allow Access" }
        return viewModel.isLastPermission ? "Start" : "Continue"
    }

    private var symbol: String {
        switch viewModel.permission {
        case .camera: "camera"
        case .photoLibrary: "photo.on.rectangle"
        case .microphone: "mic"
        case nil: "camera.aperture"
        }
    }

    private var title: String {
        switch viewModel.permission {
        case .camera: "Your camera, ready."
        case .photoLibrary: "Keep your captures."
        case .microphone: "Sound for your videos."
        case nil: "Welcome to Essential Cam"
        }
    }

    private var message: String {
        switch viewModel.permission {
        case .camera: "Allow camera access to compose and capture your photos."
        case .photoLibrary: "Save your captures and browse your gallery. You can allow all photos or select the photos you want to share."
        case .microphone: "Microphone access is used by Video mode for audio. Photos do not need it. Video recording is coming soon."
        case nil: "A simple camera. More creative control. Let's set up your permissions before your first capture."
        }
    }
}
