import Foundation

/// Datum/tijd/duur-steppers van de EventEditor — geport uit shiftDay/addMin in
/// ~/Desktop/agenda-app/src/components/EventEditor.tsx.
enum EventEditorStepping {
    /// ± dag, tijdstip blijft gelijk.
    static func shiftDay(_ date: Date, by days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// ± 15 min voor de starttijd-stepper — Date-rekenkunde rolt vanzelf over middernacht.
    static func shiftMinutes(_ date: Date, by minutes: Int) -> Date {
        date.addingTimeInterval(Double(minutes) * 60)
    }

    /// Duur-stepper, ± 15 min, nooit onder de 15.
    static func clampDuration(_ minutes: Int, delta: Int) -> Int {
        max(15, minutes + delta)
    }
}
