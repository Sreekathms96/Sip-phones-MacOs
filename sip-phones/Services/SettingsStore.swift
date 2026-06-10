import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var account: SIPAccount? {
        didSet { saveAccount() }
    }

    private let accountKey = "sipAccount"

    private init() {
        if let data = UserDefaults.standard.data(forKey: accountKey) {
            account = try? JSONDecoder().decode(SIPAccount.self, from: data)
        }
    }

    func save(account: SIPAccount, password: String) throws {
        self.account = account
        try KeychainManager.shared.savePassword(password)
    }

    func loadPassword() throws -> String? {
        try KeychainManager.shared.loadPassword()
    }

    private func saveAccount() {
        if let account, let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: accountKey)
        } else {
            UserDefaults.standard.removeObject(forKey: accountKey)
        }
    }
}
