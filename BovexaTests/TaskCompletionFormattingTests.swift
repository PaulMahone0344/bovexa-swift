import Testing
import Foundation
@testable import Bovexa

struct TaskCompletionFormattingTests {
    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return calendar.date(from: comps)!
    }

    @Test func labelForToday() {
        let now = date(2026, 7, 26, 14, 32)
        #expect(TaskCompletionFormatting.label(completedAt: now, now: now, calendar: calendar) == "Klaar om 14:32")
    }

    @Test func labelForYesterday() {
        let now = date(2026, 7, 26, 10, 0)
        let yesterday = date(2026, 7, 25, 9, 10)
        #expect(TaskCompletionFormatting.label(completedAt: yesterday, now: now, calendar: calendar) == "Klaar gisteren om 09:10")
    }

    @Test func labelForOlderDayIncludesDateAndTime() {
        let now = date(2026, 7, 26, 10, 0)
        let older = date(2026, 7, 20, 8, 5)
        let label = TaskCompletionFormatting.label(completedAt: older, now: now, calendar: calendar)
        #expect(label.hasPrefix("Klaar 20"))
        #expect(label.hasSuffix("om 08:05"))
    }
}
