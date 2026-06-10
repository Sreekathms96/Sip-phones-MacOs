import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section("SIP Account") {
                TextField("Username", text: $viewModel.username)
                    .textContentType(.username)
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                TextField("Domain", text: $viewModel.domain)
                    .textContentType(.URL)
                TextField("Port", text: $viewModel.port)
                Picker("Transport", selection: $viewModel.transport) {
                    ForEach(SIPTransport.allCases) { transport in
                        Text(transport.rawValue).tag(transport)
                    }
                }
            }

            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundStyle(.red)
            }

            Button("Save and Register") {
                viewModel.saveAndRegister()
            }
            .keyboardShortcut(.defaultAction)
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Settings")
    }
}
