//
//  Essential_CamApp.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import SwiftUI

@main
struct Essential_CamApp: App {
    @State private var presetStore = CameraPresetStore()

    var body: some Scene {
        WindowGroup {
            CameraView()
                .environment(presetStore)
                .task {
                    await presetStore.load()
                }
        }
    }
}
