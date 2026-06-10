import SwiftUI

struct ContentView: View {
    @ObservedObject private var sipService = SIPService.shared
    @ObservedObject private var logManager = LogManager.shared

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("Dialer") { DialerView() }
                NavigationLink("Active Calls") { ActiveCallView() }
                NavigationLink("History") { HistoryView() }
                NavigationLink("Settings") { SettingsView() }
                NavigationLink("Logs") { LogsView() }
            }
            .navigationTitle("SIP Phones")
        } detail: {
            DialerView()
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(sipService.registrationState.displayText)
                    .font(.callout)
                Spacer()
                Toggle("Debug", isOn: $logManager.debugLoggingEnabled)
                    .toggleStyle(.switch)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private var statusColor: Color {
        switch sipService.registrationState {
        case .registered: .green
        case .registering: .orange
        case .failed: .red
        case .unconfigured, .unregistered: .secondary
        }
    }
}
