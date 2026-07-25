import Foundation

/// Reminder-datumberekening — geport uit scheduleReminder() in ~/Desktop/agenda-app/src/lib/reminders.ts.
enum ReminderScheduling {
    /// 0 minuten = geen herinnering. Een vuurmoment op of vóór `now` wordt niet gepland
    /// (moment al voorbij).
    static func fireDate(eventStart: Date, minutesBefore: Int, now: Date = Date()) -> Date? {
        guard minutesBefore > 0 else { return nil }
        let fireAt = eventStart.addingTimeInterval(-Double(minutesBefore) * 60)
        guard fireAt > now else { return nil }
        return fireAt
    }
}
