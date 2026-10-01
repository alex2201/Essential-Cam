//
//  Essential_CamApp.swift
//  Essential Cam
//
//  Created by Alexander López on 01/09/26.
//

import SwiftUI

@main
struct Essential_CamApp: App {
#if DEBUG
    @State private var presetStore = CameraPresetStore(presets: CameraPreset.debugSamples)
#else
    @State private var presetStore = CameraPresetStore()
#endif

    var body: some Scene {
        WindowGroup {
            CameraView()
                .environment(presetStore)
        }
    }
}
