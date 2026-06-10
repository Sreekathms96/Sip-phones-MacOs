import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyIncomingCall(displayName: String, remoteURI: String) {
        let content = UNMutableNotificationContent()
        content.title = "Incoming Call"
        content.body = displayName.isEmpty ? remoteURI : displayName
        content.sound = .default
        content.categoryIdentifier = "INCOMING_CALL"

        let request = UNNotificationRequest(identifier: "incoming-call-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func registerCategories() {
        let accept = UNNotificationAction(identifier: "ACCEPT_CALL", title: "Accept", options: [.foreground])
        let reject = UNNotificationAction(identifier: "REJECT_CALL", title: "Reject", options: [])
        let category = UNNotificationCategory(identifier: "INCOMING_CALL", actions: [accept, reject], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
