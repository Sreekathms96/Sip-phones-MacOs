import Foundation
import CoreAudio

@MainActor
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published private(set) var inputDevices: [AudioDevice] = []
    @Published private(set) var outputDevices: [AudioDevice] = []
    @Published var selectedInputDevice: AudioDevice?
    @Published var selectedOutputDevice: AudioDevice?

    private let bridge = PJSIPBridge.shared()
    private var listenerInstalled = false

    private init() {}

    func start() {
        refreshDevices()
        installDeviceListener()
    }

    func refreshDevices() {
        let devices = bridge.audioDevices().map {
            AudioDevice(id: $0.deviceId, name: $0.name, inputChannels: Int($0.inputChannels), outputChannels: Int($0.outputChannels))
        }
        inputDevices = devices.filter { $0.inputChannels > 0 }
        outputDevices = devices.filter { $0.outputChannels > 0 }
        if selectedInputDevice == nil { selectedInputDevice = inputDevices.first }
        if selectedOutputDevice == nil { selectedOutputDevice = outputDevices.first }
        applySelection()
    }

    func applySelection() {
        guard let input = selectedInputDevice, let output = selectedOutputDevice else { return }
        do {
            try bridge.setInputDevice(input.id, outputDevice: output.id)
            LogManager.shared.append(.audio, "Selected input \(input.name), output \(output.name)")
        } catch {
            LogManager.shared.append(.error, error.localizedDescription)
        }
    }

    private func installDeviceListener() {
        guard !listenerInstalled else { return }
        listenerInstalled = true
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let callback: AudioObjectPropertyListenerBlock = { _, _ in
            Task { @MainActor in
                AudioManager.shared.refreshDevices()
            }
        }
        let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, callback)
        if status != noErr {
            LogManager.shared.append(.error, "Unable to listen for audio device changes: \(status)")
        }
    }
}
