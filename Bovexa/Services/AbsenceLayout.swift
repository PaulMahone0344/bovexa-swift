import Foundation

/// Baan voor een afwezigheid in het urenraster (m7 plak 4/5). `startMinutes`/
/// `durationMinutes` zijn al zo gebouwd dat ze ook een dagdeel aankunnen (plak 5) —
/// een hele dag is gewoon 0...1440.
struct AbsenceBand: Equatable {
    let event: AgendaEvent
    let column: Int
    let columnCount: Int
    let startMinutes: Double
    let durationMinutes: Double
}

/// Verdeelt afwezigheden van één dag over kolommen naast elkaar (niet gestapeld,
/// niet over elkaar heen), aan de linkerkant van het raster. Bij één afwezige is
/// er maar één kolom, dus die baan beslaat de volle beschikbare breedte.
enum AbsenceLayout {
    /// Afspraken die als blok in het raster horen. Een afwezigheid wordt als baan
    /// getekend en mag daar nooit óók als blok bij staan: sinds plak 5 is een
    /// dagdeel niet meer all-day, en zonder deze filter verscheen zo'n
    /// afwezigheid dubbel — als baan én als gewoon blok.
    static func timedNonAbsence(_ events: [AgendaEvent]) -> [AgendaEvent] {
        events.filter { !$0.allDay && $0.category != .afwezig }
    }

    static func bands(_ events: [AgendaEvent], dayStart: Date) -> [AbsenceBand] {
        let absences = events.filter { $0.category == .afwezig }.sorted { $0.start < $1.start }
        let columnCount = absences.count
        return absences.enumerated().map { index, event in
            let (start, duration) = range(for: event, dayStart: dayStart)
            return AbsenceBand(event: event, column: index, columnCount: columnCount, startMinutes: start, durationMinutes: duration)
        }
    }

    private static func range(for event: AgendaEvent, dayStart: Date) -> (Double, Double) {
        if event.allDay {
            return (0, 24 * 60)
        }
        let start = max(0, event.start.timeIntervalSince(dayStart) / 60)
        let end = event.end.map { $0.timeIntervalSince(dayStart) / 60 } ?? (24 * 60)
        return (start, max(15, end - start))
    }
}
