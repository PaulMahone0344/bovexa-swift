import Testing
import Foundation
@testable import Bovexa

/// Valkuil I: max 31 dagen per keer. Geport uit daysBetween() in afwezig.tsx.
struct AfwezigRangeTests {
    private func day(_ d: Int, _ m: Int = 8, _ y: Int = 2026) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test func singleDaySelectionProducesOneDay() {
        let days = AfwezigRange.days(from: day(3), to: day(3))
        #expect(days.count == 1)
    }

    @Test func rangeProducesInclusiveDayCount() {
        let days = AfwezigRange.days(from: day(3), to: day(5))
        #expect(days.count == 3)
    }

    @Test func exactlyThirtyOneDaysIsAllowed() {
        let days = AfwezigRange.days(from: day(1), to: day(31))
        #expect(days.count == 31)
    }

    @Test func thirtyTwoDaysExceedsMax() {
        // 1 aug t/m 1 sep = 32 dagen.
        let days = AfwezigRange.days(from: day(1, 8), to: day(1, 9))
        #expect(days.count > AfwezigRange.maxDays)
    }

    @Test func eachDayIsAtNoon() {
        let days = AfwezigRange.days(from: day(3), to: day(3))
        let comps = Calendar.current.dateComponents([.hour, .minute], from: days[0])
        #expect(comps.hour == 12 && comps.minute == 0)
    }
}
