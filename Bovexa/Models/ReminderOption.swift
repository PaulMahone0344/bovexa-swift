import Foundation

/// Herinnering-opties — geport uit REMINDER_OPTIONS in ~/Desktop/agenda-app/src/lib/reminders.ts.
struct ReminderOption: Identifiable, Equatable {
    let minutes: Int
    let label: String

    var id: Int { minutes }

    static let all: [ReminderOption] = [
        ReminderOption(minutes: 0, label: "Geen"),
        ReminderOption(minutes: 15, label: "15 min vooraf"),
        ReminderOption(minutes: 60, label: "1 uur vooraf"),
        ReminderOption(minutes: 1440, label: "1 dag vooraf"),
    ]

    static func label(for minutes: Int) -> String {
        if let vast = all.first(where: { $0.minutes == minutes }) { return vast.label }
        return vrijLabel(minutes: minutes)
    }

    /// Opschrift voor een zelfgekozen tijd, zodat "45" niet als kaal getal in beeld
    /// komt: hele dagen en hele uren krijgen hun eigen woord, de rest minuten.
    static func vrijLabel(minutes: Int) -> String {
        guard minutes > 0 else { return "Geen" }
        if minutes % 1440 == 0 {
            let dagen = minutes / 1440
            return dagen == 1 ? "1 dag vooraf" : "\(dagen) dagen vooraf"
        }
        if minutes % 60 == 0 {
            let uren = minutes / 60
            return uren == 1 ? "1 uur vooraf" : "\(uren) uur vooraf"
        }
        return "\(minutes) min vooraf"
    }
}
