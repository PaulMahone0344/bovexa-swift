import Foundation
import UserNotifications

/// Abstractie over UNUserNotificationCenter — testbaar zonder echte notificatie-permissies.
protocol NotificationScheduling {
    func currentAuthorizationGranted() async -> Bool
    func requestAuthorization() async -> Bool
    func schedule(identifier: String, title: String, body: String, fireAt: Date) async
    func cancel(identifier: String)
    /// Alles wat nog gepland staat weggooien — bij uitloggen en bij het
    /// verwijderen van een account. Zonder dit kreeg de volgende gebruiker op dit
    /// toestel "Tandarts — begint over 15 min" van zijn voorganger.
    func cancelAll()
}

final class UNNotificationScheduler: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    func currentAuthorizationGranted() async -> Bool {
        await center.notificationSettings().authorizationStatus == .authorized
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(identifier: String, title: String, body: String, fireAt: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
