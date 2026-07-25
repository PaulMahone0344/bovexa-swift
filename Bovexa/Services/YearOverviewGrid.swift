import Foundation

/// Cellen voor een mini-maand in het jaaroverzicht — geport uit monthCells() in
/// ~/Desktop/agenda-app/src/app/kalender.tsx. Maand is 0-based (jan=0), zoals JS
/// Date.getMonth(). nil = lege cel (vóór de 1e, of na de laatste dag van de maand).
/// Week begint op maandag; het aantal rijen is dynamisch (geen vaste 6 weken, anders
/// dan de hoofd-agenda's MonthGridBuilder).
enum YearOverviewGrid {
    static func monthCells(year: Int, month: Int, calendar: Calendar = .current) -> [Int?] {
        var comps = DateComponents()
        comps.year = year
        comps.month = month + 1
        comps.day = 1
        guard let firstOfMonth = calendar.date(from: comps) else { return [] }

        let weekday = calendar.component(.weekday, from: firstOfMonth) // 1 = zondag
        let offset = (weekday + 5) % 7 // maandag = 0
        let daysIn = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0

        var cells: [Int?] = Array(repeating: nil, count: offset)
        cells.append(contentsOf: stride(from: 1, through: daysIn, by: 1).map { $0 })
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }
}
