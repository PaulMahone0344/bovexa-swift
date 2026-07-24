import Foundation

struct DayGroup: Identifiable {
    let id: String // "yyyy-MM-dd"
    let day: Date
    let events: [AgendaEvent]
}

/// Lijstweergave: komende afspraken per dag gegroepeerd, chronologisch.
enum ListViewGrouping {
    static func upcomingGroupedByDay(_ events: [AgendaEvent], from now: Date, calendar: Calendar = .current) -> [DayGroup] {
        let upcoming = events
            .filter { ($0.end ?? $0.start) >= now }
            .sorted { $0.start < $1.start }

        var order: [Date] = []
        var buckets: [Date: [AgendaEvent]] = [:]

        for event in upcoming {
            let dayStart = calendar.startOfDay(for: event.start)
            if buckets[dayStart] == nil {
                buckets[dayStart] = []
                order.append(dayStart)
            }
            buckets[dayStart]?.append(event)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone

        return order.map { day in
            DayGroup(id: formatter.string(from: day), day: day, events: buckets[day] ?? [])
        }
    }
}
