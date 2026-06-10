import Foundation
import SwiftUI

@MainActor
final class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published private(set) var entries: [LogEntry] = []
    @AppStorage("debugLoggingEnabled") var debugLoggingEnabled = false

    private init() {}

    func append(_ category: LogEntry.Category, _ message: String) {
        if category == .sip && !debugLoggingEnabled { return }
        entries.insert(LogEntry(id: UUID(), category: category, message: message, timestamp: Date()), at: 0)
        if entries.count > 1_000 {
            entries.removeLast(entries.count - 1_000)
        }
    }
}
