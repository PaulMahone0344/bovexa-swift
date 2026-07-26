import Foundation

/// Combineert eigen AgendaEvents met externe agenda-events (m9 plak 4) — sortering op
/// starttijd zodat de vijf weergaves van de Agenda niet zelf hoeven te sorteren of te
/// filteren. Dit is de ene plek waar samengevoegd wordt, niet per weergave.
enum ExternalCalendarMerge {
    static func merge(_ ownEvents: [AgendaEvent], external: [DeviceCalendarEvent]) -> [AgendaEvent] {
        let mapped = external.map(ExternalEventMapper.map)
        return (ownEvents + mapped).sorted { $0.start < $1.start }
    }

    /// Marge van een maand vóór/na de zichtbare periode (valkuil G): nooit de hele
    /// historie van een externe agenda ophalen.
    static func fetchInterval(around date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.date(byAdding: .month, value: -1, to: date) ?? date
        let end = calendar.date(byAdding: .month, value: 1, to: date) ?? date
        return DateInterval(start: start, end: end)
    }
}
