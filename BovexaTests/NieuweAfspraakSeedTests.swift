import Testing
import Foundation
@testable import Bovexa

/// NieuweAfspraakSeed (M12): één voorzet, twee vertalingen — een zin voor de
/// AI-planner en een starttijd voor het handmatige formulier.
struct NieuweAfspraakSeedTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return calendar.date(from: comps)!
    }

    // MARK: - plannerSeed

    @Test func typedTextWinsOverEverythingElse() {
        let seed = NieuweAfspraakSeed(date: day(2026, 8, 3), hour: 14, text: "morgen 10:00 kapper")
        #expect(seed.plannerSeed(calendar: calendar) == "morgen 10:00 kapper")
    }

    @Test func whitespaceOnlyTextIsTreatedAsNoText() {
        let seed = NieuweAfspraakSeed(date: day(2026, 8, 3), text: "   ")
        #expect(seed.plannerSeed(calendar: calendar) == "Plan op maandag 3 augustus 2026")
    }

    @Test func dayWithHourBecomesTheHourSentence() {
        let seed = NieuweAfspraakSeed.forHour(9, on: day(2026, 8, 3))
        #expect(seed.plannerSeed(calendar: calendar) == "Plan op maandag 3 augustus 2026 om 09:00")
    }

    @Test func dayWithoutHourLeavesTheTimeToThePlanner() {
        let seed = NieuweAfspraakSeed.forDay(day(2026, 8, 3))
        #expect(seed.plannerSeed(calendar: calendar) == "Plan op maandag 3 augustus 2026")
    }

    @Test func emptySeedHasNoPlannerSentence() {
        #expect(NieuweAfspraakSeed.empty.plannerSeed(calendar: calendar) == nil)
    }

    @Test func typedTextIsTrimmed() {
        let seed = NieuweAfspraakSeed.typed("  vrijdag 15:00 tandarts  ")
        #expect(seed.plannerSeed(calendar: calendar) == "vrijdag 15:00 tandarts")
    }

    // MARK: - withText (tekstveld in de AI-kaart)

    @Test func withTextKeepsTheChosenDayAndHour() {
        let seed = NieuweAfspraakSeed.forHour(9, on: day(2026, 8, 3)).withText("kapper om 11 uur")
        #expect(seed.date == day(2026, 8, 3))
        #expect(seed.hour == 9)
        #expect(seed.plannerSeed(calendar: calendar) == "kapper om 11 uur")
    }

    /// Leeg tekstveld mag de voorzet niet wissen: dan valt de planner terug op de
    /// dag waarop de gebruiker tikte.
    @Test func withEmptyTextFallsBackToTheDaySentence() {
        let seed = NieuweAfspraakSeed.forDay(day(2026, 8, 3)).withText("   ")
        #expect(seed.plannerSeed(calendar: calendar) == "Plan op maandag 3 augustus 2026")
    }

    // MARK: - startDate

    @Test func startDateUsesTheChosenHourOnTheChosenDay() {
        let seed = NieuweAfspraakSeed.forHour(14, on: day(2026, 8, 3, hour: 7, minute: 30))
        #expect(seed.startDate(now: day(2026, 8, 1, hour: 12), calendar: calendar) == day(2026, 8, 3, hour: 14))
    }

    @Test func startDateWithoutHourOpensAtNineOnThatDay() {
        let seed = NieuweAfspraakSeed.forDay(day(2026, 8, 3, hour: 18, minute: 45))
        #expect(seed.startDate(now: day(2026, 8, 1, hour: 12), calendar: calendar) == day(2026, 8, 3, hour: 9))
    }

    @Test func startDateWithoutDayIsTheNextWholeHourFromNow() {
        let seed = NieuweAfspraakSeed.empty
        let now = day(2026, 8, 3, hour: 14, minute: 5)
        #expect(seed.startDate(now: now, calendar: calendar) == day(2026, 8, 3, hour: 15))
    }

    /// Getypte tekst zegt niets over de datum — het formulier valt dan terug op nu.
    @Test func startDateForTypedTextOnlyIsTheNextWholeHourFromNow() {
        let seed = NieuweAfspraakSeed.typed("kapper")
        let now = day(2026, 8, 3, hour: 23, minute: 40)
        #expect(seed.startDate(now: now, calendar: calendar) == day(2026, 8, 4, hour: 0))
    }
}
