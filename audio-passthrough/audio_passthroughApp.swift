//
//  audio_passthroughApp.swift
//  audio-passthrough
//
//  Created by Erwin Karim on 19/06/2025.
//

import SwiftUI

@main
struct AudioLoopbackApp: App {
    @StateObject private var audioManager = AudioManager()

    var body: some Scene {
        WindowGroup {
            ContentView(audioManager: audioManager)
                .onAppear{
                    audioManager.requestMicrophonePermission()
                }
        }
    }
}

