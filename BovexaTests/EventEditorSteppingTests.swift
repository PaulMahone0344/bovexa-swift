import Testing
import Foundation
@testable import Bovexa

/// Stepper-randen (valkuil-vrije Date-rekenkunde, maar expliciet getest per plan).
struct EventEditorSteppingTests {
    private func date(_ h: Int, _ min: Int = 0, day: Int = 3) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = day; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    // MARK: - shiftDay

    @Test func shiftDayMovesForwardKeepingTimeOfDay() {
        let result = EventEditorStepping.shiftDay(date(9, 30, day: 3), by: 1)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.day, .hour, .minute], from: result)
        #expect(comps.day == 4)
        #expect(comps.hour == 9)
        #expect(comps.minute == 30)
    }

    @Test func shiftDayMovesBackward() {
        let result = EventEditorStepping.shiftDay(date(9, day: 3), by: -1)
        let comps = Calendar(identifier: .gregorian).dateComponents([.day], from: result)
        #expect(comps.day == 2)
    }

    // MARK: - shiftMinutes (starttijd, ± 15 min)

    @Test func shiftMinutesMovesForward() {
        let result = EventEditorStepping.shiftMinutes(date(9, 0), by: 15)
        #expect(result == date(9, 15))
    }

    @Test func shiftMinutesCrossesMidnightToNextDay() {
        // 23:50 + 15 min = 00:05 de volgende dag — dag-overgang bij tijd over middernacht.
        let result = EventEditorStepping.shiftMinutes(date(23, 50, day: 3), by: 15)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.day, .hour, .minute], from: result)
        #expect(comps.day == 4)
        #expect(comps.hour == 0)
        #expect(comps.minute == 5)
    }

    @Test func shiftMinutesCrossesMidnightToPreviousDay() {
        let result = EventEditorStepping.shiftMinutes(date(0, 5, day: 3), by: -15)
        let comps = Calendar(identifier: .gregorian).dateComponents([.day, .hour, .minute], from: result)
        #expect(comps.day == 2)
        #expect(comps.hour == 23)
        #expect(comps.minute == 50)
    }

    // MARK: - clampDuration (± 15 min, min 15)

    @Test func clampDurationIncreasesFreely() {
        #expect(EventEditorStepping.clampDuration(30, delta: 15) == 45)
    }

    @Test func clampDurationNeverGoesBelowFifteen() {
        #expect(EventEditorStepping.clampDuration(15, delta: -15) == 15)
    }

    @Test func clampDurationDecreasesAboveFloor() {
        #expect(EventEditorStepping.clampDuration(45, delta: -15) == 30)
    }
}
