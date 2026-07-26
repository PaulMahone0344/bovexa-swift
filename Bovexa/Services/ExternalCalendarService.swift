import EventKit
import Foundation

/// Eén agenda van het toestel, zoals opgesomd door EventKit (m9 plak 1).
struct DeviceCalendarInfo: Identifiable, Equatable {
    let id: String
    let title: String
}

/// Eén afspraak uit een externe agenda, al losgemaakt van EKEvent zodat de rest van de
/// app (en de tests) niet met EventKit-types hoeven te werken. `id` is het rauwe
/// EKEvent-identifier; de synthetische `ext:`-id (valkuil A) komt in plak 2
/// (ExternalEventMapper).
struct DeviceCalendarEvent {
    let id: String
    let calendarId: String
    let calendarTitle: String
    let title: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
}

/// Abstractie over EKEventStore voor het UITLEZEN van agenda's — het leesequivalent van
/// `DeviceCalendarWriting` (m3). Volledige toegang nodig (valkuil F), niet de
/// write-only toegang die de bestaande sync gebruikt.
protocol DeviceCalendarReading {
    /// Al gegeven toegang uitlezen ZONDER de systeemprompt op te roepen.
    var hasFullAccess: Bool { get }
    func requestFullAccess() async -> Bool
    func availableCalendars() -> [DeviceCalendarInfo]
    func events(in interval: DateInterval, calendarIds: Set<String>) -> [DeviceCalendarEvent]
}

final class EKEventStoreCalendarReader: DeviceCalendarReading {
    private let store = EKEventStore()

    var hasFullAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestFullAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestFullAccessToEvents { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func availableCalendars() -> [DeviceCalendarInfo] {
        store.calendars(for: .event).map { DeviceCalendarInfo(id: $0.calendarIdentifier, title: $0.title) }
    }

    /// Valkuil G: alleen de opgevraagde periode, nooit de hele agenda.
    func events(in interval: DateInterval, calendarIds: Set<String>) -> [DeviceCalendarEvent] {
        guard !calendarIds.isEmpty else { return [] }
        let calendars = store.calendars(for: .event).filter { calendarIds.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        return store.events(matching: predicate).map { event in
            DeviceCalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                calendarId: event.calendar.calendarIdentifier,
                calendarTitle: event.calendar.title,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                notes: event.notes
            )
        }
    }
}

/// Leeslaag over EventKit (m9 plak 1, valkuil F/H): permissie geweigerd geeft overal een
/// lege lijst terug en nooit een crash — de app blijft dan precies werken zoals hij nu
/// werkt, zonder externe afspraken.
final class ExternalCalendarService {
    private let reader: DeviceCalendarReading

    init(reader: DeviceCalendarReading = EKEventStoreCalendarReader()) {
        self.reader = reader
    }

    var hasFullAccess: Bool { reader.hasFullAccess }

    /// Voor het openen van Profiel: nooit een prompt, alleen uitlezen wat al mag.
    /// Een systeemprompt die de gebruiker niet zelf heeft aangevraagd leest als een
    /// app die te veel wil — en één keer "Sta niet toe" is definitief.
    func calendarsIfAuthorized() -> [DeviceCalendarInfo] {
        guard reader.hasFullAccess else { return [] }
        return reader.availableCalendars()
    }

    /// Voor Profiel (m9 plak 3): granted onderscheidt "geweigerd" van "wel toegang, geen
    /// agenda's op het toestel" (valkuil F) zodat de uitlegregel alleen bij weigering komt.
    /// Roept wél de systeemprompt op — alleen aanroepen na een expliciete tik.
    func loadCalendars() async -> (granted: Bool, calendars: [DeviceCalendarInfo]) {
        let granted = await reader.requestFullAccess()
        return (granted, granted ? reader.availableCalendars() : [])
    }

    func calendars() async -> [DeviceCalendarInfo] {
        guard await reader.requestFullAccess() else { return [] }
        return reader.availableCalendars()
    }

    func events(in interval: DateInterval, calendarIds: Set<String>) async -> [DeviceCalendarEvent] {
        guard !calendarIds.isEmpty else { return [] }
        guard await reader.requestFullAccess() else { return [] }
        return reader.events(in: interval, calendarIds: calendarIds)
    }
}
