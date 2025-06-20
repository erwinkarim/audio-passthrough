//
//  ContentView.swift
//  audio-passthrough
//
//  Created by Erwin Karim on 19/06/2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        VStack(spacing: 20) {
            Text("🎧 Mac Audio Loopback")
                .font(.title)

            Picker("Input Device", selection: $audioManager.selectedInput) {
                ForEach(audioManager.inputDevices) { device in
                    Text(device.name).tag(device as AudioDevice?)
                }
            }
            .labelsHidden()
            .frame(width: 300)

            LevelMeter(level: audioManager.inputLevel)
                .frame(height: 20)
                .padding(.horizontal, 40)
            
            Button("Start Loopback") {
                audioManager.start()
            }

            Button("Stop") {
                audioManager.stop()
            }
        }
        .padding()
        .frame(width: 400, height: 250)
    }
}

#Preview {
    // The view to preview.
}
