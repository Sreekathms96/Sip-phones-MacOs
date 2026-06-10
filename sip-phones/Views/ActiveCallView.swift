import SwiftUI

struct ActiveCallView: View {
    @ObservedObject private var sipService = SIPService.shared
    @ObservedObject private var audioManager = AudioManager.shared
    @StateObject private var viewModel = ActiveCallViewModel()
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let dtmfKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
    private let columns = Array(repeating: GridItem(.fixed(52), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if sipService.activeCalls.isEmpty {
                    ContentUnavailableView("No Active Calls", systemImage: "phone", description: Text("Incoming and outgoing calls appear here."))
                } else {
                    ForEach(sipService.activeCalls) { call in
                        callPanel(call)
                    }
                }
            }
            .padding()
        }
        .onReceive(timer) { now = $0 }
        .navigationTitle("Active Calls")
    }

    private func callPanel(_ call: ActiveCall) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text(call.displayName.isEmpty ? call.remoteURI : call.displayName)
                        .font(.title3.weight(.semibold))
                    Text("\(call.state.rawValue.capitalized)  \(formattedDuration(call))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Hang Up") { viewModel.hangup(call) }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }

            if call.state == .incoming {
                HStack {
                    Button("Accept") { viewModel.accept(call) }
                        .buttonStyle(.borderedProminent)
                    Button("Reject") { viewModel.reject(call) }
                }
            }

            HStack {
                Button(call.isMuted ? "Unmute" : "Mute") { viewModel.toggleMute(call) }
                Button(call.isHeld ? "Resume" : "Hold") { viewModel.toggleHold(call) }
            }

            HStack {
                Picker("Microphone", selection: $audioManager.selectedInputDevice) {
                    ForEach(audioManager.inputDevices) { device in
                        Text(device.name).tag(Optional(device))
                    }
                }
                Picker("Speaker", selection: $audioManager.selectedOutputDevice) {
                    ForEach(audioManager.outputDevices) { device in
                        Text(device.name).tag(Optional(device))
                    }
                }
            }
            .onChange(of: audioManager.selectedInputDevice) { _, _ in audioManager.applySelection() }
            .onChange(of: audioManager.selectedOutputDevice) { _, _ in audioManager.applySelection() }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(dtmfKeys, id: \.self) { key in
                    Button(key) { viewModel.sendDTMF(key, call: call) }
                        .frame(width: 52, height: 42)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formattedDuration(_ call: ActiveCall) -> String {
        guard let connectedAt = call.connectedAt else { return "00:00" }
        let seconds = max(0, Int(now.timeIntervalSince(connectedAt)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
