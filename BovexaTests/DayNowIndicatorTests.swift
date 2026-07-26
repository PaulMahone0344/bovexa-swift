import Testing
import Foundation
@testable import Bovexa

/// Nu-lijn in de dagweergave: alleen op vandaag, en het raster opent erop.
struct DayNowIndicatorTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return calendar.date(from: comps)!
    }

    @Test func minutesMatchTimeOfDay() {
        let now = date(2026, 8, 3, 14, 30)
        let minutes = DayNowIndicator.minutesFromMidnight(now: now, day: date(2026, 8, 3), calendar: calendar)
        #expect(minutes == 870.0)
    }

    @Test func noLineOnAnotherDay() {
        let now = date(2026, 8, 3, 14, 30)
        #expect(DayNowIndicator.minutesFromMidnight(now: now, day: date(2026, 8, 4), calendar: calendar) == nil)
    }

    @Test func noLineOnYesterday() {
        let now = date(2026, 8, 3, 0, 5)
        #expect(DayNowIndicator.minutesFromMidnight(now: now, day: date(2026, 8, 2), calendar: calendar) == nil)
    }

    @Test func midnightIsZeroMinutesNotNil() {
        let now = date(2026, 8, 3, 0, 0)
        #expect(DayNowIndicator.minutesFromMidnight(now: now, day: date(2026, 8, 3), calendar: calendar) == 0)
    }

    @Test func anchorOpensAnHourBeforeNowOnToday() {
        let now = date(2026, 8, 3, 18, 40)
        #expect(DayNowIndicator.anchorHour(now: now, day: date(2026, 8, 3), calendar: calendar) == 17)
    }

    @Test func anchorNeverGoesBelowMidnight() {
        let now = date(2026, 8, 3, 0, 20)
        #expect(DayNowIndicator.anchorHour(now: now, day: date(2026, 8, 3), calendar: calendar) == 0)
    }

    @Test func anchorFallsBackToMorningOnOtherDays() {
        let now = date(2026, 8, 3, 18, 40)
        #expect(DayNowIndicator.anchorHour(now: now, day: date(2026, 8, 9), calendar: calendar) == 7)
    }
}
