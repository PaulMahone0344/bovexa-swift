import Foundation

/// Dag met minstens één afspraak — voor de badges/gemarkeerde dagen in het
/// jaaroverzicht. Maand is 0-based (jan=0), zoals JS Date.getMonth() in de RN-app.
struct EventDayKey: Hashable {
    let year: Int
    let month: Int
    let day: Int
}

enum EventDaySet {
    static func build(from events: [AgendaEvent], calendar: Calendar = .current) -> Set<EventDayKey> {
        Set(events.map { event in
            let comps = calendar.dateComponents([.year, .month, .day], from: event.start)
            return EventDayKey(year: comps.year ?? 0, month: (comps.month ?? 1) - 1, day: comps.day ?? 0)
        })
    }
}
