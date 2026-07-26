import Foundation

/// Statistiek-afleidingen voor het Vandaag-scherm.
enum VandaagStats {
    static func appointmentCount(_ events: [AgendaEvent]) -> Int {
        events.count
    }

    /// Echte afspraken: hele-dag-blokken (vakantie/ziek/vrij) tellen niet mee.
    /// "4 afspraken" op een dag met drie afspraken en één vakantiedag klopte niet.
    static func timedCount(_ events: [AgendaEvent]) -> Int {
        events.filter { !$0.allDay }.count
    }

    static func allDayCount(_ events: [AgendaEvent]) -> Int {
        events.filter(\.allDay).count
    }

    /// Bijregel onder het afspraken-cijfer, of nil als er niets afwezigs is.
    static func awayNote(_ events: [AgendaEvent]) -> String? {
        let count = allDayCount(events)
        guard count > 0 else { return nil }
        return count == 1 ? "1 afwezigheid" : "\(count) afwezigheden"
    }

    /// Hele-dag-blokken tellen niet mee: met een eindtijd erop zouden ze er in
    /// één klap 24 uur bij optellen.
    static func plannedHours(_ events: [AgendaEvent]) -> Double {
        let totalMinutes = events
            .filter { !$0.allDay }
            .reduce(0) { $0 + (EventHelpers.durationMin($1) ?? 0) }
        return Double(totalMinutes) / 60.0
    }

    /// "9 uur 45" in plaats van "9,8 uur" (verzoek opdrachtgever 26 juli): een
    /// decimaal uur moet je omrekenen voordat het iets zegt over je dag.
    /// Losse minuten blijven "45 min"; "0 uur 45" leest als een fout.
    static func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let wholeHours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if wholeHours == 0 { return minutes == 0 ? "0 uur" : "\(minutes) min" }
        if minutes == 0 { return "\(wholeHours) uur" }
        return "\(wholeHours) uur \(minutes)"
    }

    /// Aantal afspraken per dag deze week, maandag eerst (index 0 = maandag ... 6 = zondag).
    static func weekBusyCounts(_ events: [AgendaEvent], referenceDate: Date, calendar: Calendar = .current) -> [Int] {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2

        guard let weekInterval = mondayFirst.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return Array(repeating: 0, count: 7)
        }

        var counts = Array(repeating: 0, count: 7)
        for event in events {
            guard event.start >= weekInterval.start, event.start < weekInterval.end else { continue }
            let weekday = mondayFirst.component(.weekday, from: event.start) // 1=zo...7=za
            let mondayFirstIndex = (weekday + 5) % 7
            counts[mondayFirstIndex] += 1
        }
        return counts
    }
}
