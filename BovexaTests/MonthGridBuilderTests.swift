import Testing
import Foundation
@testable import Bovexa

struct MonthGridBuilderTests {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test func alwaysReturnsSixWeeksOfCells() {
        let cells = MonthGridBuilder.cells(for: date(2026, 7, 15), today: date(2026, 7, 15))
        #expect(cells.count == 42)
    }

    @Test func gridStartsOnMondayBeforeOrOnTheFirstOfTheMonth() {
        // 2026-07-01 = woensdag → grid start = 2026-06-29 (maandag).
        let cells = MonthGridBuilder.cells(for: date(2026, 7, 15), today: date(2026, 7, 15))
        let calendar = Calendar(identifier: .gregorian)
        #expect(calendar.isDate(cells[0].date, inSameDayAs: date(2026, 6, 29)))
    }

    @Test func marksDaysOutsideTheMonthAsNotCurrentMonth() {
        let cells = MonthGridBuilder.cells(for: date(2026, 7, 15), today: date(2026, 7, 15))
        #expect(cells[0].isCurrentMonth == false) // 29 juni
        let july1 = cells.first { Calendar(identifier: .gregorian).isDate($0.date, inSameDayAs: self.date(2026, 7, 1)) }
        #expect(july1?.isCurrentMonth == true)
    }

    @Test func marksTodayCorrectly() {
        let cells = MonthGridBuilder.cells(for: date(2026, 7, 15), today: date(2026, 7, 24))
        let today = cells.first { $0.isToday }
        #expect(today != nil)
        #expect(Calendar(identifier: .gregorian).isDate(today!.date, inSameDayAs: date(2026, 7, 24)))
    }
}
