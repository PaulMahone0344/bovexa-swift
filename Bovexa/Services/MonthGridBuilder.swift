import Foundation

struct MonthDayCell: Equatable, Identifiable {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool

    var id: TimeInterval { date.timeIntervalSince1970 }
}

/// Bouwt een stabiele 6-weken (42-dagen) maandgrid, maandag eerst.
enum MonthGridBuilder {
    static func cells(for month: Date, today: Date = Date(), calendar: Calendar = .current) -> [MonthDayCell] {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2

        guard
            let monthInterval = mondayFirst.dateInterval(of: .month, for: month),
            let gridStart = mondayFirst.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start
        else {
            return []
        }

        return (0..<42).map { offset in
            let day = mondayFirst.date(byAdding: .day, value: offset, to: gridStart)!
            return MonthDayCell(
                date: day,
                isCurrentMonth: mondayFirst.isDate(day, equalTo: month, toGranularity: .month),
                isToday: mondayFirst.isDate(day, inSameDayAs: today)
            )
        }
    }
}
