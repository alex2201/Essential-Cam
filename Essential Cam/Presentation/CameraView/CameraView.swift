//
//  CameraView.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import SwiftUI

struct CameraView: View {
    @State private var viewModel = CameraViewModel()

    var body: some View {
        VStack(spacing: .zero) {
            switch viewModel.cameraStatus {
            case .running:
                CameraPreview(source: viewModel.previewSource)
                    .statusBarHidden(true)
            case .failed, .interrupted:
                Text("Something went wrong")
            case .unauthorized:
                Text("Camera access is denied. Open Settings and allow access")
            case .unknown:
                ProgressView()
            }

        }
        .task {
            await viewModel.start()
        }

    }
}
