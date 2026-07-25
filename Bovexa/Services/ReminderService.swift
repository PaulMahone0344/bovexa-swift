import Foundation

/// Lokale herinnering vóór een afspraak — puur op eigen toestel, geen server-push.
/// Geport uit ~/Desktop/agenda-app/src/lib/reminders.ts. Anders dan de RN-app hoeft dit
/// geen aparte notifId-opslag bij te houden: UNNotificationRequest laat je zelf een
/// identifier kiezen, dus het event-id is meteen de annuleer-sleutel.
final class ReminderService {
    private let scheduler: NotificationScheduling

    init(scheduler: NotificationScheduling = UNNotificationScheduler()) {
        self.scheduler = scheduler
    }

    private static func identifier(for eventId: String) -> String {
        "bovexaflow_reminder_\(eventId)"
    }

    func cancel(eventId: String) {
        scheduler.cancel(identifier: Self.identifier(for: eventId))
    }

    /// Annuleert eerst een eventuele bestaande herinnering, plant dan opnieuw (bij
    /// herplannen/bewerken roept de caller dit gewoon opnieuw aan).
    func schedule(eventId: String, title: String, start: Date, minutesBefore: Int, now: Date = Date()) async {
        cancel(eventId: eventId)
        guard let fireAt = ReminderScheduling.fireDate(eventStart: start, minutesBefore: minutesBefore, now: now) else { return }

        var granted = await scheduler.currentAuthorizationGranted()
        if !granted { granted = await scheduler.requestAuthorization() }
        guard granted else { return }

        let shortLabel = ReminderOption.label(for: minutesBefore).replacingOccurrences(of: " vooraf", with: "")
        await scheduler.schedule(
            identifier: Self.identifier(for: eventId),
            title: title,
            body: "Begint over \(shortLabel)",
            fireAt: fireAt
        )
    }
}
