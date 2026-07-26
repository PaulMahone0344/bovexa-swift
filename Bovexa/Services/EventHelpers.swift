import SwiftUI

/// Tijd/duur/kleur-helpers voor AgendaEvent — geport uit ~/Desktop/agenda-app/src/lib/events.ts.
enum EventHelpers {
    private static let dutchWeekdays = ["Zondag", "Maandag", "Dinsdag", "Woensdag", "Donderdag", "Vrijdag", "Zaterdag"]
    private static let dutchMonths = [
        "januari", "februari", "maart", "april", "mei", "juni",
        "juli", "augustus", "september", "oktober", "november", "december",
    ]

    /// De ene plek waar de kleur van een afspraak bepaald wordt (m7, valkuil C).
    /// Label wint als het event er één heeft én die nog bestaat in `labelStore`;
    /// anders (geen label, of een verwijderd label) exact het oude gedrag — dat
    /// mag voor bestaande data niet veranderen (valkuil H).
    static func eventColor(_ event: AgendaEvent, labelStore: LabelStore? = nil) -> Color {
        // Valkuil D: één neutrale, gedempte behandeling voor externe events, overal
        // hetzelfde — nooit een labelkleur (die betekent "soort werk", dit is een
        // andere bron).
        if event.isExternal {
            return BovexaTheme.Colors.muted
        }
        if let labelColor = labelStore?.color(for: event.label) {
            return labelColor
        }
        if let category = event.category {
            return BovexaTheme.categoryColor(for: category)
        }
        return event.calendar == "private" ? BovexaTheme.Colors.categoryBlue : BovexaTheme.Colors.blue
    }

    static func fmtTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    static func durationMin(_ event: AgendaEvent) -> Int? {
        guard let end = event.end else { return nil }
        return Int((end.timeIntervalSince(event.start) / 60).rounded())
    }

    static func durationLabel(_ event: AgendaEvent) -> String {
        guard let minutes = durationMin(event) else { return "" }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) uur" : "\(hours) uur \(rest) min"
    }

    /// Tijdregel voor het afspraak-detail: "Hele dag", "09:00" of "09:00 · 1 uur 30 min".
    static func detailTimeText(_ event: AgendaEvent) -> String {
        if event.allDay { return "Hele dag" }
        let start = fmtTime(event.start)
        guard event.end != nil else { return start }
        return "\(start) · \(durationLabel(event))"
    }

    /// Tijdlabel voor een rij in een lijst (tijdlijn Vandaag, DaySheet,
    /// agenda-lijst, zoekresultaat). Een hele-dag-event heeft geen klok: dat
    /// toonde "00:00", en sinds het Afwezig-scherm bestaat komen die events
    /// dagelijks voorbij. Zelfde regel als `all_day ? 'Hele dag' : fmtTime(...)`
    /// in EventList.tsx / DaySheet.tsx van de RN-app.
    static func rowTimeText(_ event: AgendaEvent) -> String {
        event.allDay ? "Hele dag" : fmtTime(event.start)
    }

    /// Duur naast een rij. Bij een hele-dag-event zegt "24 uur" niets, dus leeg.
    static func rowDurationLabel(_ event: AgendaEvent) -> String {
        event.allDay ? "" : durationLabel(event)
    }

    static func sameDay(_ a: Date, _ b: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    static func eventsOnDay(_ events: [AgendaEvent], day: Date, calendar: Calendar = .current) -> [AgendaEvent] {
        events.filter { sameDay($0.start, day, calendar: calendar) }
    }

    /// Echte record-id — na uitklappen van een herhaling is dat de series_id (valkuil A).
    static func eventRecordId(_ event: AgendaEvent) -> String {
        event.seriesId ?? event.id
    }

    static func nextUpcoming(_ events: [AgendaEvent], now: Date = Date()) -> AgendaEvent? {
        events
            .filter { ($0.end ?? $0.start) >= now }
            .sorted { $0.start < $1.start }
            .first
    }

    static func longDay(_ day: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.weekday, .day, .month], from: day)
        let weekday = dutchWeekdays[(comps.weekday ?? 1) - 1]
        let month = dutchMonths[(comps.month ?? 1) - 1]
        return "\(weekday) \(comps.day ?? 0) \(month)"
    }
}
