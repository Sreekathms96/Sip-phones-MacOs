import SwiftUI

struct DialerView: View {
    @StateObject private var viewModel = DialerViewModel()
    @ObservedObject private var sipService = SIPService.shared

    private let columns = Array(repeating: GridItem(.fixed(72), spacing: 14), count: 3)

    var body: some View {
        VStack(spacing: 18) {
            TextField("Number or SIP URI", text: $viewModel.number)
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.keys, id: \.self) { key in
                    Button {
                        viewModel.append(key)
                    } label: {
                        Text(key)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .frame(width: 72, height: 56)
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 12) {
                Button("Redial") { viewModel.redial() }
                Button("Delete") { viewModel.backspace() }
                Button("Call") { viewModel.call() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(sipService.registrationState != .registered)
            }

            if sipService.registrationState != .registered {
                Text("Register a SIP account before placing calls.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Dialer")
    }
}
