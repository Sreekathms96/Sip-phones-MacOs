import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var domain = ""
    @Published var port = "5060"
    @Published var transport: SIPTransport = .udp
    @Published var errorMessage = ""

    private let settings = SettingsStore.shared
    private let sipService = SIPService.shared

    init() {
        if let account = settings.account {
            username = account.username
            domain = account.domain
            port = String(account.port)
            transport = account.transport
            password = (try? settings.loadPassword()) ?? ""
        }
    }

    func saveAndRegister() {
        errorMessage = ""
        guard let sipPort = Int(port), sipPort > 0, sipPort <= 65_535 else {
            errorMessage = "Enter a valid SIP port."
            return
        }
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty,
              !domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Username, password, and domain are required."
            return
        }

        let account = SIPAccount(username: username, domain: domain, port: sipPort, transport: transport)
        do {
            try settings.save(account: account, password: password)
            sipService.configureAndRegister(account: account, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
