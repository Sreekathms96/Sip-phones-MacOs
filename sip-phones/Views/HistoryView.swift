import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        List(viewModel.entries) { entry in
            HStack {
                Image(systemName: iconName(for: entry.direction))
                    .foregroundStyle(color(for: entry.direction))
                VStack(alignment: .leading) {
                    Text(entry.displayName.isEmpty ? entry.remoteURI : entry.displayName)
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(duration(entry.duration))
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if viewModel.entries.isEmpty {
                ContentUnavailableView("No Call History", systemImage: "clock.arrow.circlepath")
            }
        }
        .navigationTitle("History")
        .toolbar {
            Button("Refresh") { viewModel.refresh() }
        }
        .onAppear { viewModel.refresh() }
    }

    private func iconName(for direction: CallDirection) -> String {
        switch direction {
        case .incoming: "phone.arrow.down.left"
        case .outgoing: "phone.arrow.up.right"
        case .missed: "phone.down"
        }
    }

    private func color(for direction: CallDirection) -> Color {
        switch direction {
        case .incoming: .green
        case .outgoing: .blue
        case .missed: .red
        }
    }

    private func duration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
