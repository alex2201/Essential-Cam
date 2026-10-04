//
//  GalleryVideoPlayerView.swift
//  Essential Cam
//
//  Created by Codex on 04/10/26.
//

import AVKit
import SwiftUI

struct GalleryVideoPlayback: Identifiable {
    let id: String
    let player: AVPlayer
}

struct GalleryVideoPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let playback: GalleryVideoPlayback

    var body: some View {
        NavigationStack {
            VideoPlayer(player: playback.player)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Video")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done", action: dismiss.callAsFunction)
                    }
                }
                .onAppear { playback.player.play() }
                .onDisappear { playback.player.pause() }
        }
    }
}
