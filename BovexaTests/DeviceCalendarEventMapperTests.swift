import Testing
import Foundation
import EventKit
@testable import Bovexa

/// Valkuil H: tijdzone Europe/Amsterdam, vaste notitie, alleen FREQ=WEEKLY (met
/// BYDAY/UNTIL) mapt naar een herhaalregel. Geport uit deviceCalendar.ts.
struct DeviceCalendarEventMapperTests {
    private func appointment(recurrence: String? = nil, location: String? = nil) -> ProposedAppointment {
        ProposedAppointment(title: "Ketelonderhoud", date: "2026-08-03", start: "09:00", end: "10:00", category: .work, location: location, recurrence: recurrence)
    }

    @Test func mapsTimeZoneAndFixedNote() {
        let mapped = DeviceCalendarEventMapper.map(appointment())
        #expect(mapped.timeZone.identifier == "Europe/Amsterdam")
        #expect(mapped.notes == "Gemaakt vanuit Bovexa Flow.")
        #expect(mapped.title == "Ketelonderhoud")
    }

    @Test func passesThroughLocationWhenPresent() {
        let mapped = DeviceCalendarEventMapper.map(appointment(location: "Amsterdam"))
        #expect(mapped.location == "Amsterdam")
    }

    @Test func noRecurrenceMeansNoRecurrenceRule() {
        let mapped = DeviceCalendarEventMapper.map(appointment())
        #expect(mapped.recurrenceRule == nil)
    }

    @Test func nonWeeklyFrequencyIsNotMapped() {
        let rule = DeviceCalendarEventMapper.weeklyRecurrenceRule(from: "FREQ=DAILY;UNTIL=20261231")
        #expect(rule == nil)
    }

    @Test func weeklyWithoutByDayIsNotMapped() {
        let rule = DeviceCalendarEventMapper.weeklyRecurrenceRule(from: "FREQ=WEEKLY;UNTIL=20261231")
        #expect(rule == nil)
    }

    @Test func weeklyWithoutUntilIsNotMapped() {
        let rule = DeviceCalendarEventMapper.weeklyRecurrenceRule(from: "FREQ=WEEKLY;BYDAY=MO,WE")
        #expect(rule == nil)
    }

    @Test func weeklyWithByDayAndUntilMapsToRecurrenceRule() {
        let rule = DeviceCalendarEventMapper.weeklyRecurrenceRule(from: "FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261231")
        #expect(rule != nil)
        #expect(rule?.frequency == .weekly)
        #expect(rule?.interval == 1)
        let weekdays = Set(rule?.daysOfTheWeek?.map(\.dayOfTheWeek.rawValue) ?? [])
        #expect(weekdays == Set([EKWeekday.monday.rawValue, EKWeekday.wednesday.rawValue]))
    }

    @Test func untilDateEndsOnTheGivenDay() {
        let rule = DeviceCalendarEventMapper.weeklyRecurrenceRule(from: "FREQ=WEEKLY;BYDAY=MO;UNTIL=20261231")
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: rule!.recurrenceEnd!.endDate!)
        #expect(comps.year == 2026 && comps.month == 12 && comps.day == 31)
    }

    @Test func recurrenceRuleIsAttachedToMappedEventWhenValid() {
        let mapped = DeviceCalendarEventMapper.map(appointment(recurrence: "FREQ=WEEKLY;BYDAY=MO;UNTIL=20261231"))
        #expect(mapped.recurrenceRule != nil)
    }
}
