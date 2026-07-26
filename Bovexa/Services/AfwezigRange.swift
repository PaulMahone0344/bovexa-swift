import Foundation

/// Periode-logica voor het afwezig-scherm (valkuil I) — geport uit
/// daysBetween()/atNoon() in ~/Desktop/agenda-app/src/app/afwezig.tsx.
enum AfwezigRange {
    /// RN staat exact 31 dagen toe; de lus daar telt door tot 32 zodat "te lang"
    /// gedetecteerd kan worden — hier hetzelfde via `result.count <= maxDays`.
    static let maxDays = 31

    static func atNoon(_ date: Date, calendar: Calendar = .current) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }

    /// Dagen van `from` t/m `to` (inclusief), elk op het middaguur.
    static func days(from: Date, to: Date, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        var cursor = atNoon(from, calendar: calendar)
        let end = atNoon(to, calendar: calendar)
        while cursor <= end, result.count <= maxDays {
            result.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return result
    }

    /// Dag uit `day`, uur/minuut uit `time` — voor een dagdeel-afwezigheid (m7 plak 5):
    /// zelfde geselecteerde dag, maar de tijd komt uit de tijdkiezers in plaats van
    /// het middaguur.
    static func combine(day: Date, time: Date, calendar: Calendar = .current) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComps = calendar.dateComponents([.hour, .minute], from: time)
        comps.hour = timeComps.hour
        comps.minute = timeComps.minute
        comps.second = 0
        return calendar.date(from: comps) ?? day
    }
}
