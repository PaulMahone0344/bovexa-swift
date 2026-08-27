import Foundation

/// Lokale herinnering vóór een afspraak — puur op eigen toestel, geen server-push.
/// Geport uit ~/Desktop/agenda-app/src/lib/reminders.ts. Anders dan de RN-app hoeft dit
/// geen aparte notifId-opslag bij te houden: UNNotificationRequest laat je zelf een
/// identifier kiezen, dus het event-id is meteen de annuleer-sleutel.
final class ReminderService {
    private let scheduler: NotificationScheduling
    private let store: HerinneringStore

    init(scheduler: NotificationScheduling = UNNotificationScheduler(), store: HerinneringStore = .shared) {
        self.scheduler = scheduler
        self.store = store
    }

    private static func identifier(for eventId: String) -> String {
        "bovexaflow_reminder_\(eventId)"
    }

    /// De eerste tijd houdt de kale identifier — dat is de tijd die ook op de
    /// server staat. Elke tijd daarnaast krijgt het aantal minuten achter zijn id,
    /// zodat meldingen elkaar niet overschrijven.
    private static func identifier(for eventId: String, minutes: Int) -> String {
        "\(identifier(for: eventId))_\(minutes)"
    }

    func cancel(eventId: String) {
        scheduler.cancel(identifier: Self.identifier(for: eventId))
        for minuten in store.minuten(voor: eventId).dropFirst() {
            scheduler.cancel(identifier: Self.identifier(for: eventId, minutes: minuten))
        }
        store.vergeet(eventId)
    }

    /// Annuleert eerst een eventuele bestaande herinnering, plant dan opnieuw (bij
    /// herplannen/bewerken roept de caller dit gewoon opnieuw aan).
    func schedule(eventId: String, title: String, start: Date, minutesBefore: Int, now: Date = Date()) async {
        await schedule(eventId: eventId, title: title, start: start, minuten: [minutesBefore], now: now)
    }

    /// Meerdere herinneringen bij dezelfde afspraak: elke tijd wordt een eigen
    /// melding. Tijden die al voorbij zijn slaat `fireDate` over, de rest blijft
    /// gewoon staan.
    func schedule(eventId: String, title: String, start: Date, minuten: [Int], now: Date = Date()) async {
        cancel(eventId: eventId)
        let tijden = HerinneringStore.opschonen(minuten)
        guard !tijden.isEmpty else { return }

        var granted = await scheduler.currentAuthorizationGranted()
        if !granted { granted = await scheduler.requestAuthorization() }
        guard granted else { return }

        store.zet(tijden, voor: eventId)
        for (index, minutesBefore) in tijden.enumerated() {
            guard let fireAt = ReminderScheduling.fireDate(eventStart: start, minutesBefore: minutesBefore, now: now) else { continue }
            let shortLabel = ReminderOption.label(for: minutesBefore).replacingOccurrences(of: " vooraf", with: "")
            let id = index == 0 ? Self.identifier(for: eventId) : Self.identifier(for: eventId, minutes: minutesBefore)
            await scheduler.schedule(identifier: id, title: title, body: "Begint over \(shortLabel)", fireAt: fireAt)
        }
    }
}
