import EventKit
import Foundation

/// Abstractie over EKEventStore — testbaar zonder echte agenda-permissies.
protocol DeviceCalendarWriting {
    func requestWriteAccess() async -> Bool
    func writableCalendarId() -> String?
    func createEvent(_ mapped: DeviceCalendarEventMapper.MappedEvent, calendarId: String) -> Bool
}

final class EKEventStoreCalendarWriter: DeviceCalendarWriting {
    private let store = EKEventStore()

    func requestWriteAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestWriteOnlyAccessToEvents { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Voorkeur voor de standaardagenda (net als de RN-app); anders de eerste
    /// beschrijfbare agenda in de lijst. Geport uit writableCalendarId() in deviceCalendar.ts.
    func writableCalendarId() -> String? {
        if let defaultCalendar = store.defaultCalendarForNewEvents, defaultCalendar.allowsContentModifications {
            return defaultCalendar.calendarIdentifier
        }
        return store.calendars(for: .event).first { $0.allowsContentModifications }?.calendarIdentifier
    }

    func createEvent(_ mapped: DeviceCalendarEventMapper.MappedEvent, calendarId: String) -> Bool {
        guard let calendar = store.calendar(withIdentifier: calendarId) else { return false }
        let event = EKEvent(eventStore: store)
        event.title = mapped.title
        event.startDate = mapped.startDate
        event.endDate = mapped.endDate
        event.timeZone = mapped.timeZone
        event.location = mapped.location
        event.notes = mapped.notes
        event.calendar = calendar
        if let rule = mapped.recurrenceRule {
            event.addRecurrenceRule(rule)
        }
        return (try? store.save(event, span: .thisEvent)) != nil
    }
}

/// Schrijft een bevestigd AI-voorstel ook naar de iPhone Agenda (valkuil H). Permissie-
/// weigering of een uitgeschakelde voorkeur wordt stil overgeslagen — de afspraak in
/// Bovexa zelf is dan al aangemaakt en blijft gewoon staan.
final class DeviceCalendarService {
    private let writer: DeviceCalendarWriting
    private let preferenceDefaults: UserDefaults

    init(writer: DeviceCalendarWriting = EKEventStoreCalendarWriter(), preferenceDefaults: UserDefaults = .standard) {
        self.writer = writer
        self.preferenceDefaults = preferenceDefaults
    }

    @discardableResult
    func sync(_ appointment: ProposedAppointment) async -> Bool {
        await write(DeviceCalendarEventMapper.map(appointment))
    }

    /// M12-nalevering (besluit Ibrahim 21 aug): een handmatig aangemaakte afspraak
    /// gaat óók naar de iPhone Agenda. Zelfde voorkeur, zelfde permissie, zelfde
    /// stille overslag — het verschil met de AI-route zat alleen in de aanroep.
    @discardableResult
    func sync(title: String, start: Date, end: Date) async -> Bool {
        await write(DeviceCalendarEventMapper.map(title: title, start: start, end: end))
    }

    private func write(_ mapped: DeviceCalendarEventMapper.MappedEvent) async -> Bool {
        guard DeviceCalendarSyncPreference.isEnabled(defaults: preferenceDefaults) else { return false }
        guard await writer.requestWriteAccess() else { return false }
        guard let calendarId = writer.writableCalendarId() else { return false }
        return writer.createEvent(mapped, calendarId: calendarId)
    }
}
