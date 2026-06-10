import SwiftUI

struct LogsView: View {
    @ObservedObject private var logManager = LogManager.shared

    var body: some View {
        List(logManager.entries) { entry in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.category.rawValue.uppercased())
                        .font(.caption.weight(.bold))
                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Logs")
    }
}
