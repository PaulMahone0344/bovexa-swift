import Testing
import Foundation
@testable import Bovexa

/// Reminder-datumberekening — geport uit scheduleReminder() in ~/Desktop/agenda-app/src/lib/reminders.ts.
struct ReminderSchedulingTests {
    private func date(_ h: Int, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test func zeroMinutesMeansNoReminder() {
        let fireDate = ReminderScheduling.fireDate(eventStart: date(10), minutesBefore: 0, now: date(8))
        #expect(fireDate == nil)
    }

    @Test func fifteenMinutesBeforeSubtractsFromStart() {
        let fireDate = ReminderScheduling.fireDate(eventStart: date(10, 0), minutesBefore: 15, now: date(8))
        #expect(fireDate == date(9, 45))
    }

    @Test func momentAlreadyPassedSchedulesNothing() {
        // Event begint over 10 min, herinnering staat op 1 uur vooraf → vuurmoment is al voorbij.
        let fireDate = ReminderScheduling.fireDate(eventStart: date(10, 10), minutesBefore: 60, now: date(10, 0))
        #expect(fireDate == nil)
    }

    @Test func momentExactlyNowSchedulesNothing() {
        let fireDate = ReminderScheduling.fireDate(eventStart: date(10), minutesBefore: 15, now: date(9, 45))
        #expect(fireDate == nil)
    }
}

struct ReminderOptionTests {
    @Test func labelMatchesKnownMinuteValues() {
        #expect(ReminderOption.label(for: 0) == "Geen")
        #expect(ReminderOption.label(for: 15) == "15 min vooraf")
        #expect(ReminderOption.label(for: 60) == "1 uur vooraf")
        #expect(ReminderOption.label(for: 1440) == "1 dag vooraf")
    }

    @Test func unknownValueFallsBackToGeen() {
        #expect(ReminderOption.label(for: 999) == "Geen")
    }
}
