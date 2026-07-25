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
        all.first { $0.minutes == minutes }?.label ?? "Geen"
    }
}
