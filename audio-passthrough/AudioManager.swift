import Foundation
import AVFoundation
import CoreAudio
import Accelerate

class AudioManager: ObservableObject {
    private let engine = AVAudioEngine()
    private var selectedDeviceID: AudioDeviceID?
    
    @Published var inputDevices: [AudioDevice] = []
    @Published var selectedInput: AudioDevice?
    @Published var inputLevel: Float = 0.0  // 0.0 (silence) to 1.0 (max)
    
    private var levelTimer: Timer?

    init() {
        fetchInputDevices()
    }

    func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("🎤 Mic access authorized.")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print(granted ? "🎤 Mic access granted." : "❌ Mic access denied.")
            }
        case .denied, .restricted:
            print("❌ Microphone access was denied or restricted.")
        @unknown default:
            break
        }
    }

    func fetchInputDevices() {
        var deviceCount: UInt32 = 0
        var propsize = UInt32(MemoryLayout<AudioDeviceID>.size * 32)
        var devices = [AudioDeviceID](repeating: 0, count: 32)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propsize,
            &devices
        ) == noErr else {
            print("Failed to get devices")
            return
        }

        deviceCount = propsize / UInt32(MemoryLayout<AudioDeviceID>.size)

        inputDevices = devices.prefix(Int(deviceCount)).compactMap { deviceID in
            // Step 1: Check if device has input channels
            var streamFormatListSize: UInt32 = 0
            var streamConfigAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            if AudioObjectGetPropertyDataSize(deviceID, &streamConfigAddress, 0, nil, &streamFormatListSize) != noErr {
                return nil
            }

            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(streamFormatListSize))
            defer { bufferList.deallocate() }

            if AudioObjectGetPropertyData(deviceID, &streamConfigAddress, 0, nil, &streamFormatListSize, bufferList) != noErr {
                return nil
            }

            // Count the total number of input channels
            var inputChannelCount = 0
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            for buffer in buffers {
                inputChannelCount += Int(buffer.mNumberChannels)
            }

            guard inputChannelCount > 0 else {
                return nil  // Not an input-capable device
            }

            // Step 2: Get the device name
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name) != noErr {
                return nil
            }

            return AudioDevice(id: deviceID, name: name as String)
        }


        // Set default
        if let first = inputDevices.first {
            selectedInput = first
        }
    }

    func start() {
        guard let selected = selectedInput else { return }

        stop()

        let inputNode = engine.inputNode
        let mainMixer = engine.mainMixerNode
        let outputNode = engine.outputNode

        let inputFormat = inputNode.inputFormat(forBus: 0)
        let outputFormat = outputNode.outputFormat(forBus: 0)

        engine.connect(inputNode, to: mainMixer, format: inputFormat)
        engine.connect(mainMixer, to: outputNode, format: outputFormat)

        // Set the selected device
        var deviceID = selected.id
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            size,
            &deviceID
        )

        if status != noErr {
            print("⚠️ Could not set input device")
        }
        
        // Install a tap to measure signal level
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
            self.measureLevel(buffer: buffer)
        }

        do {
            try engine.start()
            print("🎤 Loopback started with input: \(selected.name)")
        } catch {
            print("❌ Failed to start engine: \(error)")
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        inputLevel = 0.0
    }
    
    private func measureLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))

        // Normalize (simple clamp for 0...1 range)
        DispatchQueue.main.async {
            self.inputLevel = min(max(rms * 10, 0), 1)
        }
    }
}

struct AudioDevice: Identifiable, Equatable, Hashable {
    var id: AudioDeviceID
    var name: String
}
