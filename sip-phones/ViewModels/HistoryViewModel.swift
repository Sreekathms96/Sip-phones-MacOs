import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var entries: [CallHistoryEntry] = []
    @Published var errorMessage = ""

    func refresh() {
        do {
            entries = try DatabaseManager.shared.loadHistory()
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
