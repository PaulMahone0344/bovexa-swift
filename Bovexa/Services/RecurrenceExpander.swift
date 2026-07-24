import Foundation

/// Klapt agenda_events.recurrence (RRULE) uit tot losse dagen (valkuil A).
/// Horizon 365 dagen zonder UNTIL, max 500 bezettingen, synthetisch id "recordId:YYYY-MM-DD".
enum RecurrenceExpander {
    static let defaultHorizonDays = 365
    static let defaultMaxOccurrences = 500

    static func expand(_ events: [AgendaEvent], maxOccurrences: Int = defaultMaxOccurrences) -> [AgendaEvent] {
        events.flatMap { expandOne($0, maxOccurrences: maxOccurrences) }
    }

    private static func expandOne(_ event: AgendaEvent, maxOccurrences: Int) -> [AgendaEvent] {
        guard
            let recurrence = event.recurrence,
            let parsed = RRule.parse(recurrence),
            parsed.freq == "WEEKLY",
            !parsed.byDay.isEmpty
        else {
            return [event]
        }

        let calendar = Calendar(identifier: .gregorian)
        let startDay = calendar.startOfDay(for: event.start)
        let durationSeconds = event.end.map { $0.timeIntervalSince(event.start) }
        let until = parsed.until ?? calendar.date(byAdding: .day, value: defaultHorizonDays, to: startDay)!
        let byDayNumbers = Set(parsed.byDay.compactMap { RRule.weekdayNumbers[$0] })
        let seriesId = event.seriesId ?? event.id

        var results: [AgendaEvent] = []
        var cursor = startDay
        var guardCount = 0

        while cursor <= until, results.count < maxOccurrences, guardCount < maxOccurrences * 8 {
            let weekday = calendar.component(.weekday, from: cursor) - 1 // 1=zondag → 0=zondag
            if byDayNumbers.contains(weekday) {
                let occurrenceStart = combine(day: cursor, timeFrom: event.start, calendar: calendar)
                let occurrenceEnd = durationSeconds.map { occurrenceStart.addingTimeInterval($0) }
                let dateKey = localDateKey(cursor, calendar: calendar)
                results.append(event.withOccurrence(
                    id: "\(event.id):\(dateKey)",
                    start: occurrenceStart,
                    end: occurrenceEnd,
                    seriesId: seriesId,
                    occurrenceDate: dateKey
                ))
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            guardCount += 1
        }

        return results
    }

    private static func combine(day: Date, timeFrom source: Date, calendar: Calendar) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: source)
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = time.hour
        comps.minute = time.minute
        comps.second = time.second
        comps.nanosecond = time.nanosecond
        return calendar.date(from: comps)!
    }

    private static func localDateKey(_ day: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
    }
}
