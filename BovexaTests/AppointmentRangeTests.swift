import Testing
import Foundation
@testable import Bovexa

/// Valkuil E: eindtijd vóór starttijd (over middernacht) → eind schuift één dag op.
/// Geport uit appointmentRange() in ~/Desktop/agenda-app/src/lib/aiPlanner.ts.
struct AppointmentRangeTests {
    private func appointment(date: String = "2026-08-03", start: String, end: String) -> ProposedAppointment {
        ProposedAppointment(title: "T", date: date, start: start, end: end, category: .work)
    }

    private func components(_ date: Date) -> DateComponents {
        Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    @Test func normalRangeStaysOnSameDay() {
        let range = AppointmentRange.range(for: appointment(start: "09:00", end: "09:30"))
        let startC = components(range.start)
        let endC = components(range.end)
        #expect(startC.day == 3 && startC.hour == 9 && startC.minute == 0)
        #expect(endC.day == 3 && endC.hour == 9 && endC.minute == 30)
    }

    @Test func endBeforeStartRollsOverToNextDay() {
        let range = AppointmentRange.range(for: appointment(start: "23:00", end: "01:00"))
        let endC = components(range.end)
        #expect(endC.day == 4 && endC.hour == 1 && endC.minute == 0)
    }

    @Test func endEqualToStartRollsOverToNextDay() {
        let range = AppointmentRange.range(for: appointment(start: "09:00", end: "09:00"))
        let endC = components(range.end)
        #expect(endC.day == 4 && endC.hour == 9)
    }
}
