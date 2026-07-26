import Foundation

/// DeviceCalendarEvent → AgendaEvent (m9 plak 2). Geen categorie, geen label, geen
/// toewijzing — dat hoort bij eigen werk, niet bij een externe agenda (valkuil D/E).
enum ExternalEventMapper {
    private static let fallbackTitle = "Afspraak"

    static func map(_ event: DeviceCalendarEvent) -> AgendaEvent {
        AgendaEvent(
            id: syntheticId(for: event),
            owner: "",
            calendar: event.calendarTitle,
            category: nil,
            title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? event.title! : fallbackTitle,
            start: event.startDate,
            end: event.endDate,
            allDay: event.isAllDay,
            recurrence: nil,
            location: event.location,
            notes: event.notes,
            klantNaam: nil,
            assigneeStatus: [:],
            seriesId: nil,
            occurrenceDate: nil,
            isExternal: true
        )
    }

    /// Valkuil A: `ext:<agenda-id>:<event-id>:<datum>` — de datum maakt twee bezettingen
    /// van dezelfde herhaling uniek, zonder EventKit's eigen recurrence-uitleg te hoeven
    /// naspelen.
    private static func syntheticId(for event: DeviceCalendarEvent) -> String {
        "ext:\(event.calendarId):\(event.id):\(dateKey(for: event.startDate))"
    }

    private static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
