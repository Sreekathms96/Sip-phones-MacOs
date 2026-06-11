import SwiftUI
import UserNotifications

@main
struct SipPhonesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 620)
                .task {
                    await appDelegate.bootstrap()
                }
        }
        Settings {
            SettingsView()
                .frame(width: 520, height: 360)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var bootstrapped = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.registerCategories()
        NotificationManager.shared.requestAuthorization()
    }

    @MainActor
    func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true
        do {
            try DatabaseManager.shared.open()
        } catch {
            LogManager.shared.append(.error, error.localizedDescription)
        }
        SIPService.shared.start(debugLogging: LogManager.shared.debugLoggingEnabled)
        AudioManager.shared.start()
        if let account = SettingsStore.shared.account, let password = try? SettingsStore.shared.loadPassword(), !password.isEmpty {
            SIPService.shared.configureAndRegister(account: account, password: password)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let actionIdentifier = response.actionIdentifier
        await MainActor.run {
            guard let incoming = SIPService.shared.activeCalls.first(where: { $0.state == .incoming }) else { return }
            switch actionIdentifier {
            case "ACCEPT_CALL", UNNotificationDefaultActionIdentifier:
                SIPService.shared.answer(callId: incoming.id)
            case "REJECT_CALL":
                SIPService.shared.reject(callId: incoming.id)
            default:
                break
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
