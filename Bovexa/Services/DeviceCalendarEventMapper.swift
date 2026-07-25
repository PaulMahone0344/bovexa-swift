import EventKit
import Foundation

/// EventKit-mapping voor een AI-voorstel (valkuil H) — geport uit
/// appointmentToDeviceCalendarEvent()/parseWeeklyRecurrence() in
/// ~/Desktop/agenda-app/src/lib/deviceCalendar.ts. Alleen FREQ=WEEKLY (met BYDAY én
/// UNTIL) wordt een herhaalregel; RRule.parse() hergebruikt dezelfde parser als
/// RecurrenceExpander (m1/m2).
enum DeviceCalendarEventMapper {
    static let timeZoneIdentifier = "Europe/Amsterdam"
    static let note = "Gemaakt vanuit Bovexa Flow."

    struct MappedEvent {
        let title: String
        let startDate: Date
        let endDate: Date
        let timeZone: TimeZone
        let location: String?
        let notes: String
        let recurrenceRule: EKRecurrenceRule?
    }

    static func map(_ appointment: ProposedAppointment, calendar: Calendar = .current) -> MappedEvent {
        let range = AppointmentRange.range(for: appointment, calendar: calendar)
        return MappedEvent(
            title: appointment.title,
            startDate: range.start,
            endDate: range.end,
            timeZone: TimeZone(identifier: timeZoneIdentifier) ?? .current,
            location: appointment.location,
            notes: note,
            recurrenceRule: appointment.recurrence.flatMap { weeklyRecurrenceRule(from: $0, calendar: calendar) }
        )
    }

    /// Valkuil H: alleen FREQ=WEEKLY met BYDAY én UNTIL wordt een herhaalregel, anders
    /// een los event (nil).
    static func weeklyRecurrenceRule(from recurrence: String, calendar: Calendar = .current) -> EKRecurrenceRule? {
        guard let parsed = RRule.parse(recurrence), parsed.freq == "WEEKLY", !parsed.byDay.isEmpty, let until = parsed.until else {
            return nil
        }
        let days: [EKRecurrenceDayOfWeek] = parsed.byDay.compactMap { day in
            guard let number = RRule.weekdayNumbers[day], let weekday = EKWeekday(rawValue: number + 1) else { return nil }
            return EKRecurrenceDayOfWeek(weekday)
        }
        guard !days.isEmpty else { return nil }

        return EKRecurrenceRule(
            recurrenceWith: .weekly, interval: 1, daysOfTheWeek: days,
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil,
            setPositions: nil, end: EKRecurrenceEnd(end: endOfDay(for: until, calendar: calendar))
        )
    }

    private static func endOfDay(for date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components) ?? date
    }
}
