import Testing
import Foundation
@testable import Bovexa

/// Seed-formattering voor lege uurslots/dagen — geport uit formatPlannerSlotSeed()
/// in ~/Desktop/agenda-app/src/lib/agendaSlots.ts.
struct PlannerSlotSeedTests {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test func formatsMondayInAugust() {
        // 3 augustus 2026 is een maandag.
        let seed = PlannerSlotSeed.forHour(9, on: day(2026, 8, 3))
        #expect(seed == "Plan op maandag 3 augustus 2026 om 09:00")
    }

    @Test func padsSingleDigitHourWithLeadingZero() {
        let seed = PlannerSlotSeed.forHour(7, on: day(2026, 8, 3))
        #expect(seed.hasSuffix("om 07:00"))
    }

    @Test func doesNotPadDoubleDigitHour() {
        let seed = PlannerSlotSeed.forHour(14, on: day(2026, 8, 3))
        #expect(seed.hasSuffix("om 14:00"))
    }

    @Test func formatsSundayCorrectly() {
        // 2 augustus 2026 is een zondag.
        let seed = PlannerSlotSeed.forHour(10, on: day(2026, 8, 2))
        #expect(seed == "Plan op zondag 2 augustus 2026 om 10:00")
    }

    @Test func formatsDecemberMonthName() {
        let seed = PlannerSlotSeed.forHour(9, on: day(2026, 12, 25))
        #expect(seed.contains("december"))
    }

    // Vanuit de dagsheet is er geen uur gekozen — dan mag de seed er ook geen
    // noemen, anders staat de planner meteen op een uur dat niemand vroeg.
    @Test func dayWithoutHourOmitsTime() {
        let seed = PlannerSlotSeed.forDay(day(2026, 8, 3))
        #expect(seed == "Plan op maandag 3 augustus 2026")
    }

    @Test func dayWithoutHourNeverMentionsAnHour() {
        let seed = PlannerSlotSeed.forDay(day(2026, 8, 2))
        #expect(!seed.contains("om "))
    }
}
